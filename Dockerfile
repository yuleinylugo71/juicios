# Usar imagen ligera oficial de Node.js
FROM node:20-alpine

# Definir directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiar manifiestos de paquetes primero para aprovechar la caché de Docker
COPY package*.json ./

# Instalar únicamente dependencias de producción
RUN npm ci --omit=dev

# Copiar el resto del código del proyecto
COPY . .

# Usar el usuario sin privilegios 'node' por seguridad en producción
USER node

# Exponer el puerto de la aplicación
EXPOSE 3000

# Variables de entorno por defecto
ENV NODE_ENV=production

# Comando de inicio del servidor
CMD ["node", "server.js"]
