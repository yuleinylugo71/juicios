# Gestion de juicios evaluativos

Sistema web en Node.js, Express y PostgreSQL para importar, consultar y analizar juicios evaluativos.

## Ejecutar localmente

1. Instala dependencias:

```bash
npm install
```

2. Crea un archivo `.env` tomando como base `.env.example`.

3. Inicia el servidor:

```bash
npm start
```

La aplicacion queda disponible en http://localhost:3000.

## Variables de entorno

- `PORT`
- `DB_HOST`
- `DB_PORT`
- `DB_USER`
- `DB_PASSWORD`
- `DB_NAME`

## Despliegue

El proyecto incluye `render.yaml` para desplegar en Render. Configura las variables de PostgreSQL en el panel de la plataforma antes de iniciar el servicio.
