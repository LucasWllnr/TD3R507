#!/bin/bash
# === Variables Globales ===
DOCKER_IMAGE="wl205938/td3r507"
KUBE_NAMESPACE="default"
CANARY_DEPLOYMENT_FILE="canary-deployment.yaml"

# === Fonctions Utilitaires ===
log_step() {
  echo "=================================="
  echo "==> $1"
  echo "=================================="
}

# === Étape 1 : Vérification des dépendances ===
log_step "Vérification des outils requis"
if ! command -v docker &> /dev/null; then
  echo "Docker n'est pas installé. Veuillez l'installer avant de continuer."
  exit 1
fi
if ! command -v kubectl &> /dev/null; then
  echo "kubectl n'est pas installé. Veuillez l'installer avant de continuer."
  exit 1
fi
if ! command -v python &> /dev/null; then
  echo "Python n'est pas installé. Veuillez l'installer avant de continuer."
  exit 1
fi

# === Étape 2 : Exécution des tests ===
log_step "Installation des dépendances et exécution des tests unitaires"
pip install -r requirements.txt
if python -m unittest discover tests; then
  echo "Tous les tests sont passés avec succès."
else
  echo "Les tests ont échoué. Abandon du pipeline."
  exit 1
fi

# === Étape 3 : Construction de l'image Docker ===
log_step "Construction de l'image Docker"
docker build -t $DOCKER_IMAGE .
if [ $? -ne 0 ]; then
  echo "La construction de l'image Docker a échoué. Abandon du pipeline."
  exit 1
fi

# === Étape 4 : Poussée de l'image Docker vers Docker Hub ===
log_step "Poussée de l'image Docker vers Docker Hub"
docker login -u "$DOCKER_USERNAME" -p "$DOCKER_PASSWORD"
docker push $DOCKER_IMAGE
if [ $? -ne 0 ]; then
  echo "La poussée de l'image Docker a échoué. Abandon du pipeline."
  exit 1
fi

# === Étape 5 : Déploiement Kubernetes ===
log_step "Déploiement de l'application sur Kubernetes"
kubectl apply -f deployment.yaml -n $KUBE_NAMESPACE
kubectl apply -f service.yaml -n $KUBE_NAMESPACE
if [ $? -ne 0 ]; then
  echo "Le déploiement Kubernetes a échoué. Vérifiez votre cluster et vos fichiers YAML."
  exit 1
fi

# === Étape 6 : Déploiement Canary (si fichier présent) ===
if [ -f "$CANARY_DEPLOYMENT_FILE" ]; then
  log_step "Application du déploiement Canary"
  kubectl apply -f $CANARY_DEPLOYMENT_FILE -n $KUBE_NAMESPACE
  if [ $? -ne 0 ]; then
    echo "Le déploiement Canary a échoué."
    exit 1
  fi
else
  echo "Fichier Canary non trouvé. Étape ignorée."
fi

# === Pipeline Terminé ===
log_step "Pipeline CI/CD terminé avec succès !"
