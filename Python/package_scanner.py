
#!/usr/bin/env python3

import subprocess
import json
import html
import os
import platform
from datetime import datetime


def run_command(command):
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=120
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    return ""


def scan_dpkg():
    packages = []
    output = run_command(["dpkg-query", "-W", "-f=${Package}\t${Version}\t${Architecture}\n"])

    for line in output.splitlines():
        parts = line.split("\t")
        if len(parts) >= 3:
            packages.append({
                "name": parts[0],
                "version": parts[1],
                "architecture": parts[2],
                "manager": "APT / dpkg"
            })

    return packages


def scan_rpm():
    packages = []
    output = run_command([
        "rpm", "-qa", "--qf",
        "%{NAME}\t%{VERSION}-%{RELEASE}\t%{ARCH}\n"
    ])

    for line in output.splitlines():
        parts = line.split("\t")
        if len(parts) >= 3:
            packages.append({
                "name": parts[0],
                "version": parts[1],
                "architecture": parts[2],
                "manager": "RPM"
            })

    return packages


def scan_pacman():
    packages = []
    output = run_command(["pacman", "-Q"])

    for line in output.splitlines():
        parts = line.split()

        if len(parts) >= 2:
            packages.append({
                "name": parts[0],
                "version": parts[1],
                "architecture": "N/A",
                "manager": "Pacman"
            })

    return packages


def scan_pip():
    packages = []

    output = run_command(["python3", "-m", "pip", "list", "--format=json"])

    if output:
        try:
            for package in json.loads(output):
                packages.append({
                    "name": package["name"],
                    "version": package["version"],
                    "architecture": "N/A",
                    "manager": "Python pip"
                })
        except json.JSONDecodeError:
            pass

    return packages


def scan_snap():
    packages = []
    output = run_command(["snap", "list"])

    for line in output.splitlines()[1:]:
        parts = line.split()

        if len(parts) >= 2:
            packages.append({
                "name": parts[0],
                "version": parts[1],
                "architecture": "N/A",
                "manager": "Snap"
            })

    return packages


def scan_flatpak():
    packages = []
    output = run_command([
        "flatpak", "list",
        "--columns=application,version,arch"
    ])

    for line in output.splitlines():
        parts = line.split("\t")

        if len(parts) >= 3:
            packages.append({
                "name": parts[0],
                "version": parts[1],
                "architecture": parts[2],
                "manager": "Flatpak"
            })

    return packages


def generate_html(packages):
    packages.sort(key=lambda p: p["name"].lower())

    rows = ""

    for package in packages:
        rows += f"""
        <tr>
            <td>{html.escape(package['name'])}</td>
            <td>{html.escape(package['version'])}</td>
            <td>{html.escape(package['architecture'])}</td>
            <td>{html.escape(package['manager'])}</td>
        </tr>
        """

    date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    document = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Linux Installed Packages Report</title>

<style>
body {{
    font-family: Arial, sans-serif;
    background: #f1f3f6;
    margin: 0;
    padding: 30px;
    color: #222;
}}

.container {{
    max-width: 1400px;
    margin: auto;
    background: white;
    padding: 30px;
    border-radius: 10px;
    box-shadow: 0 3px 15px rgba(0,0,0,.08);
}}

h1 {{ margin-top: 0; }}

.info {{
    color: #666;
    margin-bottom: 20px;
}}

.stats {{
    display: flex;
    gap: 15px;
    margin-bottom: 25px;
    flex-wrap: wrap;
}}

.stat {{
    background: #edf3fa;
    padding: 18px 25px;
    border-radius: 8px;
}}

.stat strong {{
    display: block;
    font-size: 25px;
    color: #245a91;
}}

input {{
    width: 100%;
    box-sizing: border-box;
    padding: 12px;
    margin-bottom: 15px;
    border: 1px solid #ccc;
    border-radius: 5px;
}}

table {{
    width: 100%;
    border-collapse: collapse;
}}

th, td {{
    padding: 11px;
    text-align: left;
    border-bottom: 1px solid #ddd;
}}

th {{
    background: #263b50;
    color: white;
    position: sticky;
    top: 0;
}}

tr:hover {{
    background: #f2f6fa;
}}

.footer {{
    margin-top: 25px;
    color: #888;
    font-size: 12px;
}}

@media(max-width: 700px) {{
    body {{ padding: 10px; }}
    .container {{ padding: 15px; }}
    th, td {{ padding: 7px; font-size: 12px; }}
}}
</style>
</head>

<body>
<div class="container">

<h1>Linux Installed Packages Report</h1>

<div class="info">
    Hostname: {html.escape(platform.node())}<br>
    Operating System: {html.escape(platform.platform())}<br>
    Scan date: {date}
</div>

<div class="stats">
    <div class="stat">
        <strong>{len(packages)}</strong>
        Total Installed Packages
    </div>
</div>

<input type="text" id="search" placeholder="Search packages...">

<table id="packageTable">
<thead>
<tr>
    <th>Package Name</th>
    <th>Version</th>
    <th>Architecture</th>
    <th>Package Manager</th>
</tr>
</thead>
<tbody>
{rows}
</tbody>
</table>

<div class="footer">
    Generated by Linux Package Scanner
</div>

</div>

<script>
document.getElementById("search").addEventListener("keyup", function() {{
    let filter = this.value.toLowerCase();
    let rows = document.querySelectorAll("#packageTable tbody tr");

    rows.forEach(row => {{
        row.style.display = row.innerText.toLowerCase().includes(filter)
            ? ""
            : "none";
    }});
}});
</script>

</body>
</html>
"""

    with open("installed_packages.html", "w", encoding="utf-8") as file:
        file.write(document)

    print("[+] Package scan completed!")
    print(f"[+] Total packages found: {len(packages)}")
    print("[+] HTML report: installed_packages.html")


def main():
    print("====================================")
    print("     Linux Package Scanner")
    print("====================================")

    packages = []

    scanners = [
        scan_dpkg,
        scan_rpm,
        scan_pacman,
        scan_pip,
        scan_snap,
        scan_flatpak
    ]

    for scanner in scanners:
        packages.extend(scanner())

    # Remove duplicates from identical package sources
    unique = {}
    for package in packages:
        key = (
            package["manager"],
            package["name"],
            package["version"]
        )
        unique[key] = package

    packages = list(unique.values())

    generate_html(packages)


if __name__ == "__main__":
    main()
