package io.github.brainage04.modernminecraftmodtemplate;

import io.github.brainage04.fabricmoddingconventions.ClientGameTestRecorder;
import io.github.brainage04.fabricmoddingconventions.ClientGameTestServers;

import net.fabricmc.fabric.api.client.gametest.v1.FabricClientGameTest;
import net.fabricmc.fabric.api.client.gametest.v1.context.ClientGameTestContext;


import java.util.Properties;

@SuppressWarnings("UnstableApiUsage")
public class ModernMinecraftModTemplateClientGameTest implements FabricClientGameTest {
    @Override
    public void runTest(ClientGameTestContext context) {
        Properties serverProperties = ClientGameTestServers.flatServerProperties();

        ClientGameTestServers.withDedicatedServer(context, serverProperties, "ModernMinecraftModTemplate GameTest", server -> { try {
            context.computeOnClient(client -> {
                if (!ModernMinecraftModTemplateClient.isInitialized()) {
                    throw new AssertionError("Expected the client initializer to run before the client GameTest.");
                }
        
                if (client.level == null) {
                    throw new AssertionError("Expected the client to be connected to a world during the client GameTest.");
                }
        
                if (client.player == null) {
                    throw new AssertionError("Expected the client player to be available during the client GameTest.");
                }
        
                return null;
            });
        
            ClientGameTestRecorder.startRecording(context);
            ClientGameTestRecorder.showStep(context, "template.ready", "Template client GameTest", "client initializer and world ready");
            context.waitTicks(20);
        } finally {
            ;
        } });
    }
}
