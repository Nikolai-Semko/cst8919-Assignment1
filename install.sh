echo "#!/bin/bash
echo 'Installing Python dependencies...'
pip install --upgrade pip
pip install -r requirements.txt
echo 'Dependencies installed successfully!'" > temp_deploy/install.sh

# Создать .deployment файл
echo "[config]
SCM_BUILD_ARGS = --install-requirements requirements.txt" > temp_deploy/.deployment

# Альтернативный .deployment файл
echo "[config]
command = bash install.sh" > temp_deploy/.deployment

# Пересоздать ZIP архив
powershell "Compress-Archive -Path 'temp_deploy\*' -DestinationPath 'deploy_with_build.zip' -Force"

# Развернуть с принудительной установкой зависимостей
az webapp deploy \
  --resource-group rg-auth0-security-lab \
  --name auth0-security-lab-93823-202507062302 \
  --src-path deploy_with_build.zip \
  --type zip