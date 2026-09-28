package io.github.brainage04.modernminecraftmodtemplate.config;

import io.github.brainage04.modernminecraftmodtemplate.ModernMinecraftModTemplate;
import me.fzzyhmstrs.fzzy_config.api.ConfigApi;
import me.fzzyhmstrs.fzzy_config.api.RegisterType;
import me.fzzyhmstrs.fzzy_config.config.Config;
import me.fzzyhmstrs.fzzy_config.config.ConfigSection;
import me.fzzyhmstrs.fzzy_config.validation.minecraft.ValidatedIdentifier;
import me.fzzyhmstrs.fzzy_config.validation.misc.ValidatedBoolean;
import me.fzzyhmstrs.fzzy_config.validation.misc.ValidatedChoice;
import me.fzzyhmstrs.fzzy_config.validation.misc.ValidatedEnum;
import me.fzzyhmstrs.fzzy_config.validation.misc.ValidatedString;
import me.fzzyhmstrs.fzzy_config.validation.number.ValidatedDouble;
import me.fzzyhmstrs.fzzy_config.validation.number.ValidatedInt;
import net.minecraft.resources.Identifier;

import java.util.List;
import java.util.function.Supplier;

public class ModConfig extends Config {
    public static final ModConfig CONFIG =
            ConfigApi.registerAndLoadConfig((Supplier<ModConfig>) ModConfig::new, RegisterType.BOTH);

    // Bare values serialize, but validated wrappers are what drive correction and auto-GUI generation.
    public double fallbackDamageMultiplier = 1.25D;
    public ValidatedBoolean logConfigOnStartup = new ValidatedBoolean(true);
    public ValidatedString welcomeMessage = new ValidatedString("Configured with Fzzy Config");
    public ValidatedInt startupRetries = new ValidatedInt(3, 10, 0);
    public ValidatedDouble alertThreshold = new ValidatedDouble(0.65D, 1.0D, 0.0D);
    public ValidatedChoice<String> broadcastStyle = new ValidatedChoice<>(
            "compact",
            List.of("compact", "verbose", "silent"),
            new ValidatedString(),
            ValidatedChoice.WidgetType.CYCLING
    );
    public ValidatedEnum<SyncMode> syncMode =
            new ValidatedEnum<>(SyncMode.BALANCED, ValidatedEnum.WidgetType.CYCLING);
    public ValidatedIdentifier featuredItem = new ValidatedIdentifier("minecraft", "nether_star");
    public GameplaySection gameplay = new GameplaySection();

    public ModConfig() {
        super(Identifier.fromNamespaceAndPath(ModernMinecraftModTemplate.MOD_ID, "settings"));
    }

    public static void init() {
        // Touch the singleton during common init so the config is loaded and registered early.
    }

    public enum SyncMode {
        CONSERVATIVE,
        BALANCED,
        AGGRESSIVE
    }

    public static class GameplaySection extends ConfigSection {
        public ValidatedBoolean enableExperimentalRules = new ValidatedBoolean(false);
        public ValidatedInt bonusLives = new ValidatedInt(1, 5, 0);
        public ValidatedString statusPrefix = new ValidatedString("[Example]");
    }
}
