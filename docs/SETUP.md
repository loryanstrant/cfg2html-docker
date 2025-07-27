# Repository Setup Guide

This document provides setup instructions for the GitHub Container Registry (GHCR) integration and repository configuration.

## GitHub Container Registry (GHCR) Setup

### Automatic Configuration

The repository is configured to automatically publish Docker images to GHCR using the built-in `GITHUB_TOKEN`. No additional secrets are required for basic functionality.

### Package Visibility Settings

1. Navigate to your repository's **Settings** → **Actions** → **General**
2. Under "Workflow permissions", ensure:
   - ✅ "Read and write permissions" is selected
   - ✅ "Allow GitHub Actions to create and approve pull requests" is checked

3. After the first successful build, go to your profile/organization **Packages** tab
4. Find the `cfg2html-docker` package and update visibility settings as needed:
   - **Public**: Anyone can pull the image
   - **Private**: Only you and collaborators can access

## Required Permissions

The workflow requires the following permissions (automatically granted to `GITHUB_TOKEN`):

- `contents: read` - To checkout the repository
- `packages: write` - To push images to GHCR
- `security-events: write` - To upload security scan results (implicit)

## Manual Workflow Dispatch

The workflow can be triggered manually with environment selection:

1. Go to **Actions** tab in your repository
2. Select "Build and Push Docker Image" workflow  
3. Click **"Run workflow"**
4. Choose environment:
   - `test` - For development testing
   - `staging` - For staging environment
   - `production` - For production releases

## Workflow Triggers

The workflow automatically runs on:

- **Push to main/master branch**: Builds and pushes with `latest` tag
- **Push tags** (v*): Builds and pushes with semantic version tags
- **Pull Requests**: Builds and tests (no push to registry)
- **Manual dispatch**: Builds and pushes based on selected environment

## Image Tags

Images are automatically tagged based on the trigger:

- `latest` - Latest commit on main/master branch
- `main`, `master` - Branch-specific tags
- `pr-123` - Pull request specific tags (testing only)
- `v1.2.3` - Semantic version tags from git tags
- `1.2`, `1` - Major/minor version tags from semantic versions

## Multi-Platform Support

Images are built for:
- `linux/amd64` (Intel/AMD 64-bit)
- `linux/arm64` (ARM 64-bit, including Apple Silicon)

## Security Scanning

- **Trivy** vulnerability scanner runs on all pushed images
- Results are uploaded to GitHub Security tab
- Critical vulnerabilities will create alerts

## Troubleshooting

### Permission Denied Errors

If you see permission errors:

1. Check repository workflow permissions in Settings → Actions → General
2. Verify your account has admin access to the repository
3. Ensure GHCR is enabled for your account/organization

### Build Failures

If builds fail:

1. Check the Actions tab for detailed logs
2. Verify Dockerfile syntax with `docker build` locally
3. Run `./test.sh` locally to test functionality
4. Check for any recent changes to base image or dependencies

### GHCR Access Issues

If image pulls fail:

1. Verify package visibility settings
2. For private packages, ensure proper authentication:
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
   ```
3. Check if package exists in GitHub Packages tab

## Local Development

To test changes locally:

```bash
# Build the image
docker build -t cfg2html-docker-local .

# Run comprehensive tests
./test.sh

# Test basic functionality
docker run --rm -e HOSTS="127.0.0.1" -e RUN_AT_STARTUP="false" cfg2html-docker-local echo "Test passed"
```

## Support

For issues with:
- **Workflow/CI**: Check GitHub Actions documentation
- **GHCR**: Check GitHub Packages documentation  
- **Container functionality**: See main README.md troubleshooting section