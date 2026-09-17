package main

deny[msg] {
	result := input.Results[_]
	vuln := result.Vulnerabilities[_]
	vuln.Severity == "CRITICAL"
	vuln.FixedVersion != ""
	msg := sprintf("CRITICAL vulnerability with fix available: %s in %s (installed: %s, fix: %s)", [vuln.VulnerabilityID, vuln.PkgName, vuln.InstalledVersion, vuln.FixedVersion])
}
