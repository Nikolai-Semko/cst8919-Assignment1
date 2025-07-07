import json
from os import environ as env
from urllib.parse import quote_plus, urlencode
from authlib.integrations.flask_client import OAuth
from dotenv import find_dotenv, load_dotenv
from flask import Flask, redirect, render_template, session, url_for
from datetime import datetime
import logging # <-- Добавлено

# Load environment variables
ENV_FILE = find_dotenv()
if ENV_FILE:
    load_dotenv(ENV_FILE)

# Initialize Flask app
app = Flask(__name__)
app.secret_key = env.get("APP_SECRET_KEY")

# --- Новая часть: Настройка логирования ---
# Azure App Service будет перехватывать логи, отправленные в stdout/stderr.
# Используем базовую конфигурацию, чтобы логи выводились в консоль.
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s %(levelname)s: %(message)s',
                    datefmt='%Y-%m-%d %H:%M:%S')

logger = logging.getLogger(__name__)
# ---------------------------------------------


# Custom Jinja2 filter to convert Unix timestamp to readable date
@app.template_filter('datetime')
def datetime_filter(timestamp):
    if timestamp:
        try:
            dt = datetime.fromtimestamp(int(timestamp))
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

# Routes
@app.route("/")
def home():
    return render_template("home.html", session=session.get('user'), pretty=json.dumps(session.get('user'), indent=4))

@app.route("/login")
def login():
    return oauth.auth0.authorize_redirect(
        redirect_uri=url_for("callback", _external=True)
    )

@app.route("/callback", methods=["GET", "POST"])
def callback():
    token = oauth.auth0.authorize_access_token()
    session["user"] = token
    
    # --- Новая часть: Логирование успешного входа ---
    user_info = token.get('userinfo')
    log_data = {
        "event": "user_login_success",
        "user_id": user_info.get('sub'),
        "email": user_info.get('email'),
        "timestamp": datetime.now().isoformat()
    }
    # Используем json.dumps для структурированного лога
    logger.info(json.dumps(log_data))
    # ------------------------------------------------

    return redirect("/")

@app.route("/logout")
def logout():
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

@app.route("/protected")
def protected():
    # Check if user is authenticated
    if 'user' not in session:
        # --- Новая часть: Логирование неавторизованного доступа ---
        log_data = {
            "event": "unauthorized_access_attempt",
            "path": "/protected",
            "timestamp": datetime.now().isoformat()
        }
        logger.warning(json.dumps(log_data))
        # --------------------------------------------------------
        return redirect(url_for('login'))
    
    # User is authenticated, show protected content
    # --- Новая часть: Логирование доступа к защищенному роуту ---
    user_info = session['user'].get('userinfo')
    log_data = {
        "event": "protected_access",
        "user_id": user_info.get('sub'),
        "email": user_info.get('email'),
        "timestamp": datetime.now().isoformat()
    }
    logger.info(json.dumps(log_data))
    # -------------------------------------------------------

    return render_template("protected.html", user=session['user'])

# Server instantiation
if __name__ == "__main__":
    port = int(env.get("PORT", 3000))
    app.run(host="0.0.0.0", port=port, debug=True)