# cfg2html Docker Configuration Examples

## Basic Configuration with Password Authentication

```yaml
# docker-compose.yml
version: '3.8'

services:
  cfg2html:
    image: ghcr.io/loryanstrant/cfg2html-docker:latest
    environment:
      HOSTS: "192.168.1.10:22:root:mypassword,192.168.1.11:22:admin:adminpass"
      TZ: "America/New_York"
      CRON_SCHEDULE: "0 2 * * 1"  # 2am every Monday
    volumes:
      - ./output:/app/output
      - ./logs:/var/log/cfg2html
```

## Advanced Configuration with SSH Keys

```yaml
# docker-compose.yml
version: '3.8'

services:
  cfg2html:
    image: ghcr.io/loryanstrant/cfg2html-docker:latest
    environment:
      HOSTS: "web1.example.com:22:deploy:/app/keys/web1_key,db1.example.com:2222:postgres:/app/keys/db_key"
      TZ: "Europe/London"
      CRON_SCHEDULE: "0 3 * * 0"  # 3am every Sunday
      RUN_AT_STARTUP: "true"
    volumes:
      - ./output:/app/output
      - ./ssh-keys:/app/keys:ro
      - ./logs:/var/log/cfg2html
```

## Multiple Environments Configuration

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  cfg2html-prod:
    image: ghcr.io/loryanstrant/cfg2html-docker:latest
    environment:
      HOSTS: "prod-web1:22:deploy:${PROD_PASSWORD},prod-db1:22:postgres:${DB_PASSWORD}"
      TZ: "UTC"
      CRON_SCHEDULE: "0 2 * * 1"
    volumes:
      - ./output/prod:/app/output
    networks:
      - production

  cfg2html-staging:
    image: ghcr.io/loryanstrant/cfg2html-docker:latest
    environment:
      HOSTS: "stage-web1:22:deploy:${STAGE_PASSWORD},stage-db1:22:postgres:${DB_PASSWORD}"
      TZ: "UTC"
      CRON_SCHEDULE: "0 1 * * 1"
    volumes:
      - ./output/staging:/app/output
    networks:
      - staging

networks:
  production:
    external: true
  staging:
    external: true
```

## Environment Variables File

```bash
# .env
TZ=America/New_York
SSH_PORT=22
SSH_USER=admin
CRON_SCHEDULE=0 2 * * 1
RUN_AT_STARTUP=true
LOG_LEVEL=INFO

# Sensitive credentials (use Docker secrets in production)
PROD_PASSWORD=secure_prod_password
STAGE_PASSWORD=secure_stage_password
DB_PASSWORD=secure_db_password
```