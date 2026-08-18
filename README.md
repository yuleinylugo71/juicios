# Gestion de juicios evaluativos

Sistema web en Node.js, Express y PostgreSQL para importar, consultar y analizar juicios evaluativos.

## Ejecutar localmente (Sin Docker)

1. Instala dependencias:

```bash
npm install
```

2. Crea un archivo `.env` tomando como base `.env.example`.

3. Inicia el servidor:

```bash
npm start
```

La aplicacion queda disponible en `http://localhost:3000`.

---

## Despliegue en VPS con Docker y Docker Compose

### 1. Clonar el repositorio en el VPS y preparar variables
```bash
git clone <tu-repositorio-url>
cd "gestion juicios"
cp .env.example .env
nano .env   # Ajusta las contraseñas y puerto deseado
```

### 2. (Opcional) Inicializar Base de Datos
Si tienes un archivo `.sql` inicial o backup, colócalo dentro de la carpeta `init-db/`. Se ejecutará automáticamente la primera vez que inicie PostgreSQL.

### 3. Levantar los contenedores
```bash
docker compose up --build -d
```

### 4. Comandos útiles en el VPS
- **Ver logs**:
  ```bash
  docker compose logs -f app
  ```
- **Detener servicios**:
  ```bash
  docker compose down
  ```
- **Reiniciar servicios**:
  ```bash
  docker compose restart
  ```

---

## Variables de entorno

- `PORT`: Puerto expuesto en el host (por defecto `3000`).
- `DB_HOST`: Host de la base de datos (`db` cuando se usa Docker Compose).
- `DB_PORT`: Puerto de PostgreSQL (`5432`).
- `DB_USER`: Usuario de la base de datos.
- `DB_PASSWORD`: Contraseña de la base de datos.
- `DB_NAME`: Nombre de la base de datos.
