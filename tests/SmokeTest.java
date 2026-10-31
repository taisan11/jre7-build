import javax.net.ssl.SSLContext;
import java.awt.GraphicsEnvironment;

public final class SmokeTest {
    public static void main(String[] args) throws Exception {
        String version = System.getProperty("java.specification.version");
        if (!"1.7".equals(version)) {
            throw new AssertionError("Expected Java 7, got " + version);
        }
        if (SSLContext.getDefault() == null) {
            throw new AssertionError("Missing default TLS context");
        }
        // AWT must remain available for old LWJGL 2 and game launchers.
        GraphicsEnvironment.isHeadless();
        System.out.println("PASS: Java " + version + ", TLS and AWT present");
    }
}
