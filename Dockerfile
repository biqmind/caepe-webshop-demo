FROM nginx:latest

# Copy HTML files to nginx default root directory
COPY files/html /usr/share/nginx/html