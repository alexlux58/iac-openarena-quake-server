# Ansible Files Directory

This directory contains files needed for deployment that are too large or sensitive to include in git.

## Required Files for QuakeJS

To deploy QuakeJS, you need to place the following files in this directory:

1. **`pak0.pk3`** (required)
   - OpenArena/Quake game file (~450MB)
   - Copy from your QuakeFiles directory: `cp /path/to/QuakeFiles/pak0.pk3 ansible/files/pak0.pk3`
   - This file is required for QuakeJS to run

2. **`quakejs_images.tar`** (optional but recommended)
   - Pre-built Docker image tar file (~1GB)
   - Copy from your QuakeFiles directory: `cp /path/to/QuakeFiles/quakejs_images.tar ansible/files/quakejs_images.tar`
   - If not provided, the deployment will attempt to pull `sayterdarkwoulf/quakejs:latest` from Docker Hub
   - Using the tar file is faster and more reliable

## File Sizes

- `pak0.pk3`: ~450MB
- `quakejs_images.tar`: ~1GB

## Git Considerations

These files are large and may not be suitable for git repositories. Consider:

1. **Git LFS**: Use Git Large File Storage for these files
2. **External Storage**: Store on S3 and download during deployment
3. **Documentation**: Document where users can obtain these files

## Current Files

- `openarena-0.8.8.zip` - OpenArena dedicated server (not used for QuakeJS)

