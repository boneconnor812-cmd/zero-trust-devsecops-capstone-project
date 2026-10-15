package main

# =============================================================================
# Trivy Vulnerability Gate Policy
# =============================================================================
# PURPOSE: Block container images with CRITICAL vulnerabilities that have
#          available fixes. This enforces NIST SP 800-53 RA-5 (Vulnerability
#          Monitoring and Scanning) and SI-2 (Flaw Remediation).
#
# EXCEPTION: OWASP Juice Shop is an intentionally vulnerable application
#            used as a penetration testing target. Its CVEs are acknowledged
#            and accepted risks — the app runs in an isolated namespace with
#            Cilium network policies, Kyverno pod security, and Falco
#            runtime monitoring as compensating controls.
# =============================================================================

# Accepted CVEs for OWASP Juice Shop (intentionally vulnerable test target)
# Each CVE is documented here as a formal risk acceptance — similar to a
# POA&M (Plan of Action & Milestones) entry in RMF.
accepted_cves := {
    # jsonwebtoken < 4.2.2 — algorithm confusion allows token forgery
    "CVE-2015-9235",
    # lodash < 4.17.12 — prototype pollution
    "CVE-2019-10744",
    # crypto-js < 4.2.0 — PBKDF2 output truncation weakens encryption
    "CVE-2023-46233",
    # crypto-js < 4.0.0 — related crypto weakness
    "CVE-2026-71851",
    # handlebars < 4.7.10 — template injection
    "CVE-2026-106445",
    # handlebars < 4.7.10 — related template injection
    "CVE-2026-106446",
    # tar < 7.5.19 — path traversal on extraction
    "CVE-2026-59873",
}

deny[msg] {
    result := input.Results[_]
    vuln := result.Vulnerabilities[_]
    vuln.Severity == "CRITICAL"
    vuln.FixedVersion != ""

    # Only deny if the CVE is NOT in our accepted exception list
    not accepted_cves[vuln.VulnerabilityID]

    msg := sprintf("CRITICAL vulnerability with fix available: %s in %s (installed: %s, fix: %s)", [vuln.VulnerabilityID, vuln.PkgName, vuln.InstalledVersion, vuln.FixedVersion])
}
