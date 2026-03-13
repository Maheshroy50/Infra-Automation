# One-Click Auto-Deploy for Flask + React

This repo is set up for the Talrn infrastructure task: push to `main`, GitHub Actions SSHes into the server, and `deploy.sh` rebuilds and redeploys the app.

The original template keeps the frontend and backend under `src/apps/frontend` and `src/apps/backend`, so the deployment flow uses those real paths while still matching the assignment requirements.

## What is included

- `deploy.sh`: idempotent deployment script with logging, `git pull`, frontend build, backend virtualenv setup, Gunicorn restart, and Nginx reload
- `.github/workflows/deploy.yml`: GitHub Actions workflow using `appleboy/ssh-action`
- `nginx-snippet.conf`: Nginx config that serves the React build and proxies `/api/` to Gunicorn over a Unix socket
- `terraform/`: Terraform code that provisions an EC2 instance and uses `user_data` to install dependencies, clone the repo, configure systemd and Nginx, and run the first deployment
- `src/apps/backend/requirements.txt`: runtime dependency file so the backend can be installed with `python -m venv` and `pip install -r requirements.txt`

## Deployment flow

On every push to `main`:

1. GitHub Actions connects to the server with `appleboy/ssh-action`.
2. `deploy.sh` runs on the server.
3. The script pulls the latest code with `git pull --ff-only`.
4. The React app is rebuilt with `npm ci` and `npm run build`.
5. Built frontend files are synced to `/var/www/html`.
6. The Python backend venv is created or reused at `src/apps/backend/venv`.
7. The backend dependencies are installed from `src/apps/backend/requirements.txt`.
8. Gunicorn is restarted on `unix:/tmp/app.sock`.
9. Nginx is reloaded.

Deployment logs are written to `/var/www/flask-react-app/deploy.log`.

## Provision the server with Terraform

Terraform is the cleanest way to present this task because the EC2 box can be created and bootstrapped from code.

### What the `user_data` script does

When the EC2 instance starts for the first time, `terraform/modules/app_server/user_data.sh.tftpl`:

- installs Git, Nginx, Python 3, `python3-venv`, `rsync`, and Node.js 22
- installs and starts Redis for the backend's Celery configuration
- clones your fork into `/var/www/flask-react-app`
- installs a systemd unit called `flask-react-app.service`
- installs the provided Nginx site config
- runs the first deployment automatically

### Terraform steps

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set at least:

- `repository_url` to your GitHub fork URL
- `allowed_ssh_cidr` to your IP range if you want SSH locked down

Then run:

```bash
terraform init
terraform apply
```

Useful outputs:

```bash
terraform output instance_public_ip
terraform output app_url
terraform output generated_private_key_path
terraform output ssh_command
```

Terraform now generates the EC2 SSH key pair automatically and saves the private key locally as `terraform/<app_name>.pem`.
Do not commit that file. It is already ignored in `.gitignore`.

Bootstrap logs on the server:

- `/var/log/flask-react-app-bootstrap.log`
- `journalctl -u flask-react-app.service`

## GitHub Actions secrets

In your GitHub repo go to `Settings -> Secrets and variables -> Actions` and add:

- `SERVER_HOST`: value from `terraform output -raw instance_public_ip`
- `SERVER_USER`: `ubuntu`
- `SERVER_SSH_KEY`: contents of the private key file at the path returned by `terraform output -raw generated_private_key_path`
- `SERVER_PORT`: `22`

After that, every push to `main` triggers the deploy workflow in `.github/workflows/deploy.yml`.

## Nginx reverse proxy

The included [`nginx-snippet.conf`](nginx-snippet.conf) does two things:

- serves the React build from `/var/www/html`
- proxies `/api/` to `unix:/tmp/app.sock`

That means requests to `/api/...` go to Flask, and everything else falls back to `index.html` for the React SPA.

## Optional runtime environment

The Terraform bootstrap writes an example file at `/etc/flask-react-app.env`.

It now writes safe defaults for:

```bash
CELERY_BROKER_URL=redis://...
CELERY_RESULT_BACKEND=redis://...
WEB_APP_HOST=http://localhost
```

If you want the full backend features to work, also add:

```bash
MONGODB_URI=mongodb://...
```

For the deployment assessment itself, the important part is the one-click build and redeploy pipeline.

## How to test the task

1. Change something visible in the frontend, for example text in [`about.page.tsx`](src/apps/frontend/pages/about/about.page.tsx).
2. Commit and push to `main`.
3. Open the `Actions` tab in GitHub and watch `Deploy to Production`.
4. After the job succeeds, refresh `http://<server-ip>` and confirm the change is live.

## Notes for the reviewer

- The deploy script is safe to rerun.
- `rsync --delete` keeps frontend files clean across deploys.
- The workflow has concurrency enabled so overlapping pushes do not race each other.
- The first server setup is automated with Terraform and `user_data`, not by manual SSH steps.

## Original project docs

- [Getting Started](docs/getting-started.md)
- [Backend Architecture](docs/backend-architecture.md)
- [Frontend Architecture](docs/frontend-architecture.md)
- [Deployment Notes](docs/deployment.md)
