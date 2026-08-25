# Proofline Projects Pages deployment

This directory publishes the validated **Proofline Projects v3.1** portfolio as a namespaced subsite of the already enabled `Infotechcompany/thebuddysystems` GitHub Pages site.

Expected public path:

```text
https://infotechcompany.github.io/thebuddysystems/proofline-projects/
```

## Integrity model

The source release is reconstructed from ordered transport parts and must match:

```text
f44f22da0241b6ca23a897bd5de3ecd2ec6666fe51eb81aa37fec4f1847a9cbe  proofline-projects-v3.1-public-site.zip
```

`build-pages-subsite.sh` then:

1. tests ZIP integrity;
2. verifies the upstream internal `SHA256SUMS` manifest before adaptation;
3. validates JavaScript and JSON syntax;
4. rejects symbolic links and obvious secret or local-path disclosure patterns;
5. adapts only the 404 stylesheet path for namespaced hosting;
6. records deployment provenance; and
7. regenerates and verifies the deployed derivative manifest.

Pull requests receive validation only. Pages write and OIDC permissions are granted only to the post-merge deployment job. All third-party actions are pinned to full commit SHAs.

## Rollback

Revert the deployment merge commit or rerun the last known-good Pages deployment. Any release-part mutation changes the reconstructed archive hash and fails closed until the pinned identity is deliberately reviewed and updated.

## Scope boundary

This deployment does not alter the Docker Compose application, Portainer templates, secrets, database state, or operational configuration in this repository. It also preserves the portfolio's explicit exclusions: no field-plant performance claim for synthetic metrics, no profitable-trading claim, no arbitrary private-key recovery, no full-width secp256k1 break, and no control-system actuation authority.
