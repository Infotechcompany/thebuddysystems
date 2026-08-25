#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-.}"
output_dir="${2:-_site}"
cd "$repo_root"

archive="${RUNNER_TEMP:-/tmp}/proofline-projects-v3.1-public-site.zip"
unpacked="${RUNNER_TEMP:-/tmp}/proofline-projects-v3.1-unpacked"
release_dir="proofline-portfolio/releases"
release_sha256="f44f22da0241b6ca23a897bd5de3ecd2ec6666fe51eb81aa37fec4f1847a9cbe"

rm -f "$archive"
cat "$release_dir"/proofline-projects-v3.1-public-site.zip.part* > "$archive"
echo "$release_sha256  $archive" | sha256sum --check --strict -
unzip -tq "$archive"

rm -rf "$unpacked" "$output_dir"
mkdir -p "$unpacked" "$output_dir/proofline-projects"
unzip -q "$archive" -d "$unpacked"
source_dir="$unpacked/proofline-projects-v3.1-public-site"
test -d "$source_dir"

(
  cd "$source_dir"
  sha256sum --check --strict SHA256SUMS
)

cp -a "$source_dir/." "$output_dir/proofline-projects/"
sed -i \
  's|href="/assets/styles.css"|href="assets/styles.css"|' \
  "$output_dir/proofline-projects/404.html"

cat > "$output_dir/proofline-projects/DEPLOYMENT_PROVENANCE.json" <<'JSON'
{
  "schema_version": "proofline.pages-deployment-provenance.v1",
  "upstream_release": "proofline-projects-v3.1-public-site.zip",
  "upstream_sha256": "f44f22da0241b6ca23a897bd5de3ecd2ec6666fe51eb81aa37fec4f1847a9cbe",
  "upstream_repository": "Infotechcompany/AI_PROJECTS",
  "upstream_commit": "b5996a962b17a15d545481522724de122f06c749",
  "deployment_repository": "Infotechcompany/thebuddysystems",
  "deployment_path": "/proofline-projects/",
  "adaptation": "The 404 stylesheet reference is changed from origin-root absolute to subsite-relative after upstream verification."
}
JSON
printf '3.1.1-pages-subpath\n' > "$output_dir/proofline-projects/VERSION"

node --check "$output_dir/proofline-projects/assets/app.js"
python -m json.tool "$output_dir/proofline-projects/data/projects.json" >/dev/null
python -m json.tool "$output_dir/proofline-projects/DEPLOYMENT_PROVENANCE.json" >/dev/null

test -s "$output_dir/proofline-projects/index.html"
test -s "$output_dir/proofline-projects/404.html"
test -s "$output_dir/proofline-projects/assets/styles.css"
test -f "$output_dir/proofline-projects/.nojekyll"

if find "$output_dir" -type l -print -quit | grep -q .; then
  echo "Refusing symbolic links in the Pages payload." >&2
  exit 1
fi

if grep -RInE \
  'BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY|sk-[A-Za-z0-9_-]{20,}|/home/david|C:\\Users\\david' \
  "$output_dir"; then
  echo "Potential private key, token, or local-path disclosure detected." >&2
  exit 1
fi

cp "$output_dir/proofline-projects/404.html" "$output_dir/404.html"
sed -i \
  's|href="assets/styles.css"|href="/thebuddysystems/proofline-projects/assets/styles.css"|' \
  "$output_dir/404.html"
: > "$output_dir/.nojekyll"

(
  cd "$output_dir/proofline-projects"
  find . -type f ! -name SHA256SUMS -print0 \
    | sort -z \
    | xargs -0 sha256sum > SHA256SUMS
  sha256sum --check --strict SHA256SUMS
)

printf 'Validated Proofline Projects v3.1.1 at /thebuddysystems/proofline-projects/\n'
