# DashTime GitHub Pages

This directory contains the files for the DashTime project's GitHub Pages site.

## Structure

- `index.html`: Main landing page
- `CNAME`: Custom domain configuration for dashtime.site

## Updating the Site

1. Make changes to the files in this directory
2. Commit and push the changes to the main branch
3. GitHub will automatically deploy the changes to GitHub Pages

## Custom Domain Setup

The site is configured to use the custom domain dashtime.site. The DNS configuration should be set up on Namecheap as follows:

### Namecheap DNS Configuration
- Type: A Record, Host: @, Value: 185.199.108.153
- Type: A Record, Host: @, Value: 185.199.109.153
- Type: A Record, Host: @, Value: 185.199.110.153
- Type: A Record, Host: @, Value: 185.199.111.153
- Type: CNAME Record, Host: www, Value: [your-github-username].github.io 