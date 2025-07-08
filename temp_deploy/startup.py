# startup.py for Azure App Service
import os
from server import app

if __name__ == '__main__':
    # Azure App Service sets the PORT environment variable
    port = int(os.environ.get('PORT', 3000))
    app.run(host='0.0.0.0', port=port, debug=False)