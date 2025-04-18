# DashTime GitHub Pages

This directory contains the files for the DashTime project's GitHub Pages site.

## Structure

- `index.html`: Main landing page
- `CNAME`: Custom domain configuration for dashtime.site

## Updating the Site

1. Make changes to the files in this directory
2. Commit and push the changes to the main branch
3. GitHub will automatically deploy the changes to GitHub Pages

## GitHub Pages Setup

To enable GitHub Pages with your custom domain:

1. Go to your GitHub repository
2. Navigate to Settings > Pages
3. Under "Build and deployment":
   - Set Source to "Deploy from a branch"
   - Set Branch to "main" and folder to "/docs"
   - Click Save
4. Under "Custom domain":
   - Enter "dashtime.site"
   - Click Save
   - Check "Enforce HTTPS" after DNS propagation is complete

## Custom Domain Setup

The site is configured to use the custom domain dashtime.site. Configure your Namecheap DNS settings as follows:

### Namecheap DNS Configuration
- Type: A Record, Host: @, Value: 185.199.108.153
- Type: A Record, Host: @, Value: 185.199.109.153
- Type: A Record, Host: @, Value: 185.199.110.153
- Type: A Record, Host: @, Value: 185.199.111.153
- Type: CNAME Record, Host: www, Value: yourusername.github.io (replace "yourusername" with your actual GitHub username)

Note: DNS changes can take up to 48 hours to fully propagate. 