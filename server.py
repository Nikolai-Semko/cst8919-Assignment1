import json
import logging
from os import environ as env
from urllib.parse import quote_plus, urlencode
from authlib.integrations.flask_client import OAuth
from dotenv import find_dotenv, load_dotenv
from flask import Flask, redirect, render_template, session, url_for, request
from datetime import datetime

# Load environment variables
ENV_FILE = find_dotenv()
if ENV_FILE:
    load_dotenv(ENV_FILE)

# Initialize Flask app
app = Flask(__name__)
app.secret_key = env.get("APP_SECRET_KEY")

# Configure logging for Azure Monitor
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Custom Jinja2 filter to convert Unix timestamp to readable date
@app.template_filter('datetime')
def datetime_filter(timestamp):
    """Convert Unix timestamp to readable datetime string"""
    if timestamp:
        try:
            # Convert Unix timestamp to datetime object
            dt = datetime.fromtimestamp(int(timestamp))
            # Format as readable string
            return dt.strftime('%B %d, %Y at %I:%M:%S %p')
        except (ValueError, TypeError):
            return "Invalid date"
    return "No expiration"

# Configure OAuth
oauth = OAuth(app)

oauth.register(
    "auth0",
    client_id=env.get("AUTH0_CLIENT_ID"),
    client_secret=env.get("AUTH0_CLIENT_SECRET"),
    client_kwargs={
        "scope": "openid profile email",
    },
    server_metadata_url=f'https://{env.get("AUTH0_DOMAIN")}/.well-known/openid-configuration'
)

def log_user_activity(activity_type, user_info=None, additional_data=None):
    """Log structured user activity for Azure Monitor"""
    log_data = {
        'timestamp': datetime.utcnow().isoformat(),
        'activity_type': activity_type,
        'source_ip': request.remote_addr,
        'user_agent': request.headers.get('User-Agent', 'Unknown'),
        'endpoint': request.endpoint,
        'url': request.url
    }
    
    if user_info:
        log_data.update({
            'user_id': user_info.get('userinfo', {}).get('sub', 'unknown'),
            'user_email': user_info.get('userinfo', {}).get('email', 'unknown'),
            'user_name': user_info.get('userinfo', {}).get('name', 'unknown')
        })
    
    if additional_data:
        log_data.update(additional_data)
    
    # Log as structured JSON for easier parsing in Azure Monitor
    logger.info(f"USER_ACTIVITY: {json.dumps(log_data)}")

# Routes
@app.route("/")
def home():
    return render_template("home.html", session=session.get('user'), pretty=json.dumps(session.get('user'), indent=4))

@app.route("/login")
def login():
    # Log login attempt
    log_user_activity("login_attempt")
    
    return oauth.auth0.authorize_redirect(
        redirect_uri=url_for("callback", _external=True)
    )

@app.route("/callback", methods=["GET", "POST"])
def callback():
    try:
        token = oauth.auth0.authorize_access_token()
        session["user"] = token
        
        # Log successful login
        log_user_activity("login_success", user_info=token)
        
        return redirect("/")
    except Exception as e:
        # Log failed login
        log_user_activity("login_failure", additional_data={'error': str(e)})
        logger.error(f"Login callback error: {str(e)}")
        return redirect("/")

@app.route("/logout")
def logout():
    user_info = session.get('user')
    
    # Log logout
    log_user_activity("logout", user_info=user_info)
    
    session.clear()
    return redirect(
        "https://" + env.get("AUTH0_DOMAIN")
        + "/v2/logout?"
        + urlencode(
            {
                "returnTo": url_for("home", _external=True),
                "client_id": env.get("AUTH0_CLIENT_ID"),
            },
            quote_via=quote_plus,
        )
    )

# Protected route - Lab requirement with enhanced logging
@app.route("/protected")
def protected():
    # Check if user is authenticated
    if 'user' not in session:
        # Log unauthorized access attempt
        log_user_activity("unauthorized_access_attempt", additional_data={'target_route': '/protected'})
        logger.warning("Unauthorized access attempt to /protected route")
        
        # Redirect to login if not authenticated
        return redirect(url_for('login'))
    
    # Log successful access to protected route
    user_info = session.get('user')
    log_user_activity("protected_route_access", user_info=user_info)
    
    # User is authenticated, show protected content
    return render_template("protected.html", user=session['user'])

# Health check endpoint for monitoring
@app.route("/health")
def health():
    return {
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'auth0-flask-app'
    }

# Activity statistics endpoint (for testing)
@app.route("/api/activity")
def activity_stats():
    if 'user' not in session:
        return {"error": "Unauthorized"}, 401
    
    user_info = session.get('user')
    log_user_activity("activity_stats_access", user_info=user_info)
    
    return {
        'message': 'Activity statistics endpoint',
        'user': user_info.get('userinfo', {}).get('email', 'unknown'),
        'timestamp': datetime.utcnow().isoformat()
    }

# Server instantiation
if __name__ == "__main__":
    port = int(env.get("PORT", 3000))
    app.run(host="0.0.0.0", port=port, debug=env.get("FLASK_DEBUG", "False").lower() == "true")