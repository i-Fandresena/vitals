# Espace d'administration Vitals — build statique servi par nginx.

FROM node:22-slim AS builder
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

# L'adresse de l'API est figée au build : Vite remplace les import.meta.env
# par leur valeur. Changer de serveur impose donc de reconstruire l'image.
ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL

COPY . .
RUN npm run build

FROM nginx:1.27-alpine AS runner
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
