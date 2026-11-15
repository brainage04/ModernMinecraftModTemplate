package io.github.brainage04.modernminecraftmodtemplate.init;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.net.URI;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;
import java.util.stream.Stream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;
import org.objectweb.asm.AnnotationVisitor;
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassVisitor;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.tree.ClassNode;
import org.spongepowered.asm.mixin.MixinEnvironment;
import org.spongepowered.asm.mixin.extensibility.IMixinConfigPlugin;
import org.spongepowered.asm.mixin.extensibility.IMixinInfo;

/**
 * Registers every class in the mixin package as a mixin, so the mixin configurations list none by
 * hand.
 *
 * <p>Mixin calls {@link #getMixins()} once per config, after the environment's side is known
 * (MixinConfig.postInitialise). The config whose package ends in {@code .client} is returned only
 * on the physical client, and the other configs never return a class from a {@code client}
 * sub-package, so a dedicated server loads no client mixin: those name client-only classes, and
 * loading one there fails the server at startup.
 *
 * <p>Adapted from lineargraph/Forge1.8.9Template 09cd2809.
 */
public class AutoDiscoveryMixinPlugin implements IMixinConfigPlugin {
    private static final String CLIENT_PACKAGE = "client.";
    private static final String MIXIN_DESCRIPTOR = "Lorg/spongepowered/asm/mixin/Mixin;";

    /**
     * System property prefix under which each config's registered mixins are published, for the
     * GameTest that checks a dedicated server loads no client mixin. A system property, not a
     * static field: Mixin loads this class in its own class loader, so a field here is not the one
     * the game code sees.
     */
    public static final String REGISTERED_PROPERTY = "modernminecraftmodtemplate.registeredMixins.";

    private String mixinPackage;
    private List<String> mixins;

    @Override
    public void onLoad(String mixinPackage) {
        this.mixinPackage = mixinPackage;
    }

    @Override
    public List<String> getMixins() {
        if (mixins != null) {
            return mixins;
        }

        List<String> found = new ArrayList<>();
        collect(found);

        boolean clientConfig = mixinPackage.endsWith(".client");
        boolean clientSide =
                MixinEnvironment.getCurrentEnvironment().getSide() == MixinEnvironment.Side.CLIENT;
        List<String> selected = new ArrayList<>();
        for (String mixin : found) {
            if (clientConfig) {
                if (clientSide) {
                    selected.add(mixin);
                }
            } else if (!mixin.startsWith(CLIENT_PACKAGE)) {
                selected.add(mixin);
            }
        }

        mixins = Collections.unmodifiableList(selected);
        List<String> qualified = new ArrayList<>();
        for (String mixin : selected) {
            qualified.add(mixinPackage + "." + mixin);
        }
        System.setProperty(REGISTERED_PROPERTY + mixinPackage, String.join(",", qualified));
        return mixins;
    }

    /**
     * Adds every class of the mixin package to {@code found}.
     *
     * <p>The search starts from this class's own resource, not from its code source: a loader may
     * report a code source that is not where the classes are (NeoForge's TransformingClassLoader
     * reports the mod's first path), and it need not serve directory resources at all. This class
     * sits in the same class root as the mixins, so its resource URL gives that root in a
     * development run (a directory) and in a built jar alike.
     */
    private void collect(List<String> found) {
        String ownResource = getClass().getSimpleName() + ".class";
        URL own = getClass().getResource(ownResource);
        if (own == null) {
            throw new IllegalStateException("Cannot locate " + ownResource + " to find the mixins");
        }

        String ownPath = getClass().getName().replace(".", "/") + ".class";
        String url = own.toString();
        int classRootEnd = url.length() - ownPath.length();
        if (classRootEnd < 0 || !url.endsWith(ownPath)) {
            throw new IllegalStateException("Unexpected location for " + ownResource + ": " + url);
        }
        String classRoot = url.substring(0, classRootEnd);

        if (classRoot.startsWith("jar:")) {
            String jarPath = classRoot.substring(4).split("!")[0];
            try (ZipInputStream zis =
                    new ZipInputStream(Files.newInputStream(Paths.get(URI.create(jarPath))))) {
                ZipEntry next;
                while ((next = zis.getNextEntry()) != null) {
                    addMixin(next.getName(), readAll(zis), found);
                    zis.closeEntry();
                }
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
            return;
        }

        Path directory;
        try {
            directory = Paths.get(URI.create(classRoot));
        } catch (IllegalArgumentException e) {
            throw new RuntimeException("Cannot read the class root " + classRoot, e);
        }
        Path mixinRoot = directory.resolve(mixinPackage.replace(".", "/"));
        if (!Files.isDirectory(mixinRoot)) {
            return;
        }
        try (Stream<Path> classes = Files.walk(mixinRoot)) {
            classes.filter(Files::isRegularFile)
                    .forEach(
                            it -> {
                                try {
                                    addMixin(
                                            directory.relativize(it).toString(),
                                            Files.readAllBytes(it),
                                            found);
                                } catch (IOException e) {
                                    throw new UncheckedIOException(e);
                                }
                            });
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    private static byte[] readAll(InputStream in) throws IOException {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int read;
        while ((read = in.read(buffer)) != -1) {
            out.write(buffer, 0, read);
        }
        return out.toByteArray();
    }

    /**
     * Adds a class file to {@code found} as a name relative to the mixin package, if it is inside
     * that package and carries {@code @Mixin}.
     *
     * <p>The annotation decides, not the name: an anonymous or nested class of a mixin is part of
     * that mixin and Mixin rejects it ("is missing an @Mixin annotation",
     * MixinInfo.readDeclaredTargets), which fails the whole config because it is {@code required}.
     * A static nested class that does carry {@code @Mixin} is a mixin of its own and Mixin applies
     * it, so skipping every name with a {@code $} would silently drop it.
     */
    private void addMixin(String classFile, byte[] bytes, List<String> found) {
        if (!classFile.endsWith(".class")) {
            return;
        }
        String name =
                classFile.substring(0, classFile.length() - ".class".length())
                        .replace("\\", "/")
                        .replace("/", ".");
        String prefix = mixinPackage + ".";
        if (!name.startsWith(prefix) || name.endsWith(".") || !isMixin(bytes)) {
            return;
        }
        found.add(name.substring(prefix.length()));
    }

    private static boolean isMixin(byte[] bytes) {
        boolean[] annotated = new boolean[1];
        new ClassReader(bytes)
                .accept(
                        new ClassVisitor(Opcodes.ASM9) {
                            @Override
                            public AnnotationVisitor visitAnnotation(
                                    String descriptor, boolean visible) {
                                if (MIXIN_DESCRIPTOR.equals(descriptor)) {
                                    annotated[0] = true;
                                }
                                return null;
                            }
                        },
                        ClassReader.SKIP_CODE | ClassReader.SKIP_DEBUG | ClassReader.SKIP_FRAMES);
        return annotated[0];
    }

    @Override
    public void preApply(
            String targetClassName,
            ClassNode targetClass,
            String mixinClassName,
            IMixinInfo mixinInfo) {}

    @Override
    public void postApply(
            String targetClassName,
            ClassNode targetClass,
            String mixinClassName,
            IMixinInfo mixinInfo) {}

    @Override
    public String getRefMapperConfig() {
        return null;
    }

    @Override
    public boolean shouldApplyMixin(String targetClassName, String mixinClassName) {
        return true;
    }

    @Override
    public void acceptTargets(Set<String> myTargets, Set<String> otherTargets) {}
}
