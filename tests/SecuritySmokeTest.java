import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.security.Security;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocket;

public final class SecuritySmokeTest {
    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }

    public static void main(String[] args) throws Exception {
        String value = Security.getProperty("jdk.tls.disabledAlgorithms");
        require(value != null, "Missing jdk.tls.disabledAlgorithms");
        Set<String> blocked = new HashSet<String>();
        for (String entry : value.split(",")) {
            blocked.add(entry.trim());
        }
        for (String entry : new String[] {
                "SSLv3", "TLSv1", "TLSv1.1", "RC4", "ECDH",
                "DES", "3DES_EDE_CBC", "anon", "NULL" }) {
            require(blocked.contains(entry), "TLS policy missing: " + entry);
        }

        SSLContext context = SSLContext.getInstance("TLS");
        context.init(null, null, null);
        SSLSocket socket = (SSLSocket) context.getSocketFactory().createSocket();
        try {
            Set<String> enabled = new HashSet<String>(
                    Arrays.asList(socket.getEnabledProtocols()));
            require(enabled.contains("TLSv1.2"), "TLS 1.2 is not enabled");
            require(!enabled.contains("TLSv1"), "TLS 1.0 is enabled");
            require(!enabled.contains("TLSv1.1"), "TLS 1.1 is enabled");
            require(!enabled.contains("SSLv3"), "SSL 3.0 is enabled");
        } finally {
            socket.close();
        }

        File blacklist = new File(System.getProperty("java.home"),
                "lib/security/blacklisted.certs");
        require(blacklist.isFile(), "Certificate blacklist is missing");
        int fingerprints = 0;
        boolean foundNewEntry = false;
        BufferedReader reader = new BufferedReader(new FileReader(blacklist));
        try {
            String line = reader.readLine();
            require("Algorithm=SHA-256".equals(line),
                    "Unexpected certificate blacklist hash algorithm");
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (line.length() == 0 || line.startsWith("#")) {
                    continue;
                }
                require(line.matches("[0-9A-F]{64}"),
                        "Invalid certificate blacklist fingerprint");
                if (line.equals(
                        "0164D7CEAE5BB909C272AF151FF44B1177AE9B47D9424B94F1D9558C30934D19")) {
                    foundNewEntry = true;
                }
                fingerprints++;
            }
        } finally {
            reader.close();
        }
        require(fingerprints >= 86,
                "Outdated certificate blacklist: " + fingerprints + " entries");
        require(foundNewEntry, "Missing 2026 OpenJDK 8u blacklist additions");
        System.out.println("Java 7 TLS / certificate blacklist smoke test passed ("
                + fingerprints + " entries)");
    }
}
