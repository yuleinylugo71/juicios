# Inicialización de Base de Datos

Cualquier archivo `.sql` o `.sh` colocado en esta carpeta será ejecutado automáticamente por PostgreSQL la **primera vez** que se cree el volumen de la base de datos.

Si tienes un volcado de tu base de datos (por ejemplo `schema.sql` o `backup.sql`), puedes colocarlo aquí antes de ejecutar `docker compose up -d`.
