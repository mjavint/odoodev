# odoodev

Imagen de desarrollo para Odoo publicada en GHCR.

## Imagen en GHCR

- Repositorio: ghcr.io/mjavint/odoodev
- Tags esperados:
  - latest en la rama principal
  - nombre de rama al hacer push a cualquier rama (por ejemplo: feature-x)
  - sha corto del commit

## 1) Descargar la imagen

Si la imagen es publica:

```bash
docker pull ghcr.io/mjavint/odoodev:latest
```

Si necesitas un tag especifico:

```bash
docker pull ghcr.io/mjavint/odoodev:3.12-slim-bookworm
```

O con el nombre de una rama:

```bash
docker pull ghcr.io/mjavint/odoodev:main
```

## 2) Login en GHCR (opcional)

Como el paquete es publico, puedes hacer `docker pull` sin login.

Si aun asi quieres autenticarte (por ejemplo, para evitar limites o preparar push), usa
un token de GitHub con alcance `read:packages`:

```bash
echo "TU_TOKEN" | docker login ghcr.io -u TU_USUARIO_GITHUB --password-stdin
```

## 3) Ejecutar el contenedor para desarrollo

Ejemplo montando tu proyecto en /workspace y persistiendo historial:

```bash
docker run --rm -it \
	--name odoodev \
	-v "$PWD":/workspace \
	-v odoodev_history:/commandhistory \
	ghcr.io/mjavint/odoodev:latest
```

## 4) Configuracion recomendada

- Directorio de trabajo: /workspace
- Shell por defecto: zsh
- Usuario dentro del contenedor: odoo
- Virtualenv recomendado del proyecto: .venv dentro de /workspace

Si quieres exponer una carpeta de datos de Odoo:

```bash
docker run --rm -it \
	-v "$PWD":/workspace \
	-v odoo_data:/var/lib/odoo \
	ghcr.io/mjavint/odoodev:latest
```

## 5) Verificar que la imagen esta disponible

```bash
docker images | grep ghcr.io/mjavint/odoodev
```

Y para validar dentro del contenedor:

```bash
python --version
zsh --version
```
