import os
from flask import Flask, request, Response, stream_with_context
import requests
from urllib.parse import urlparse, urlunparse

app = Flask(__name__)

# Configuration for allowed origins (for Access-Control-Allow-Origin header)
# Use '*' for development, but for production, list specific origins:
# e.g., ALLOWED_ORIGINS = os.environ.get('ALLOWED_ORIGINS', 'http://localhost:3000,https://your-frontend-app.com').split(',')
ALLOWED_ORIGINS = os.environ.get('ALLOWED_ORIGINS', '*').split(',')

# Configuration for allowed target hosts (for security, prevent proxying to arbitrary sites)
# For development, you might leave this empty or use '*', but for production, be specific:
# e.g., ALLOWED_TARGET_HOSTS = os.environ.get('ALLOWED_TARGET_HOSTS', 'api.example.com,jsonplaceholder.typicode.com').split(',')
ALLOWED_TARGET_HOSTS = os.environ.get('ALLOWED_TARGET_HOSTS', '*').split(',')

# --- Helper function to add CORS headers ---
def add_cors_headers(response, origin):
    """Adds CORS headers to the Flask response."""
    if '*' in ALLOWED_ORIGINS:
        response.headers['Access-Control-Allow-Origin'] = '*'
    elif origin and origin in ALLOWED_ORIGINS:
        response.headers['Access-Control-Allow-Origin'] = origin
    else:
        # If origin is not allowed, set a default or just return without CORS headers
        # For strict security, you might not set ACAO at all if origin is not allowed
        response.headers['Access-Control-Allow-Origin'] = 'null' # Or remove this line

    response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS, PATCH'
    response.headers['Access-Control-Allow-Headers'] = \
        'Origin, X-Requested-With, Content-Type, Accept, Authorization'
    response.headers['Access-Control-Allow-Credentials'] = 'true'
    response.headers['Access-Control-Max-Age'] = '86400' # Cache preflight for 24 hours
    return response

# --- Main proxy route ---
# This route handles all incoming requests and forwards them
@app.route('/<path:target_url>', methods=['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'])
def proxy(target_url):
    """
    Proxies the request to the target_url.
    The target_url is expected to be the full URL (e.g., http://example.com/api/data)
    passed as part of the path after the proxy's base URL.
    """
    # Get the original 'Origin' header from the client request
    origin = request.headers.get('Origin')

    # Reconstruct the target URL from the path
    # Flask's path converter automatically decodes, so we need to be careful
    # to ensure the scheme and netloc are correctly handled.
    # For example, if target_url is "http://example.com/api", it comes in as "http://example.com/api"
    # We need to ensure it's a valid URL before making the request.
    
    # Prepend 'http://' if missing to ensure urlparse works correctly, then remove if it was actually HTTPS
    # This is a common pattern for cors-anywhere like proxies.
    if not target_url.startswith(('http://', 'https://')):
        target_url = 'http://' + target_url # Default to http if not specified

    parsed_url = urlparse(target_url)

    # Basic security check: Validate the target host
    if '*' not in ALLOWED_TARGET_HOSTS:
        if parsed_url.hostname not in ALLOWED_TARGET_HOSTS:
            app.logger.warning(f"Blocked request to unauthorized target host: {parsed_url.hostname}")
            response = Response("Unauthorized target host", status=403)
            return add_cors_headers(response, origin)

    # Handle OPTIONS (preflight) requests
    if request.method == 'OPTIONS':
        response = Response(status=204) # 204 No Content for successful preflight
        return add_cors_headers(response, origin)

    # Prepare headers for the forwarded request
    headers = {key: value for key, value in request.headers if key.lower() not in ['host', 'origin', 'connection', 'content-length']}
    
    # If the original request has a Content-Type, ensure it's passed
    if 'Content-Type' in request.headers:
        headers['Content-Type'] = request.headers['Content-Type']

    try:
        # Forward the request to the target URL
        req_method = request.method
        req_data = request.get_data() # Get raw request body

        app.logger.info(f"Proxying {req_method} request to: {target_url}")

        # Stream the response to handle potentially large files
        # verify=False is generally NOT recommended for production due to security risks.
        # Use a proper CA bundle or trusted certificates in production.
        # For a simple proxy, we might allow it for flexibility, but warn the user.
        proxied_response = requests.request(
            method=req_method,
            url=target_url,
            headers=headers,
            data=req_data,
            stream=True, # Enable streaming for potentially large responses
            verify=False # WARNING: Do not use in production without understanding risks
        )

        # Create a Flask response and stream content from the proxied response
        response = Response(stream_with_context(proxied_response.iter_content(chunk_size=8192)),
                            status=proxied_response.status_code,
                            content_type=proxied_response.headers.get('Content-Type'))

        # Copy relevant headers from the proxied response to the client response
        # Exclude hop-by-hop headers that are handled by the proxy itself
        excluded_headers = ['content-encoding', 'content-length', 'transfer-encoding', 'connection']
        for key, value in proxied_response.headers.items():
            if key.lower() not in excluded_headers:
                response.headers[key] = value

        # Add CORS headers to the final response
        return add_cors_headers(response, origin)

    except requests.exceptions.RequestException as e:
        app.logger.error(f"Error proxying request to {target_url}: {e}")
        response = Response(f"Proxy Error: {e}", status=500)
        return add_cors_headers(response, origin)
    except Exception as e:
        app.logger.error(f"An unexpected error occurred: {e}")
        response = Response(f"Internal Proxy Error: {e}", status=500)
        return add_cors_headers(response, origin)

if __name__ == '__main__':
    # Get port from environment variable, default to 8080
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
