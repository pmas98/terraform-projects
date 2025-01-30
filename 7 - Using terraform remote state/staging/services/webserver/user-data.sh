#!/bin/bash

# Create the web directory and index file
mkdir -p /var/www/html
cat > /var/www/html/index.xhtml <<EOF
<h1>Hello, World</h1>
<p>DB address: ${db_address}</p>
<p>DB port: ${db_port}</p>
EOF

# Start a Python HTTP server in the background
nohup python3 -m http.server ${server_port} --directory /var/www/html &