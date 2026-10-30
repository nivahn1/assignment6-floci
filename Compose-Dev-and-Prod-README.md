# Running the development and production versions of the app with Docker only

This project demonstrates deploying a Compose-based app to Kubernetes on an
emulated AWS EKS cluster. It's a stage-2 lab where students take a Docker
Compose stack, generate Kubernetes manifests, push the image to ECR, and deploy
to EKS in [Floci](https://github.com/floci-io/floci), a local AWS emulator,
with guidance from the K8s Floci Tutor teaching agent.

## Application architecture

See [Application Architecture](./docs/ARCHITECTURE.md) for the client component tree and the backend REST API routes.

This sample application is a simple React frontend that receives data from a
Node.js backend.

When the application is packaged and shipped, the frontend is compiled into
static HTML, CSS, and JS and then bundled with the backend where it is then
served as static assets. So no... there is no server-side rendering going on
with this sample app.

During development, since the backend and frontend need different dev tools,
they are split into two separate services. This allows [Vite](https://vitejs.dev/)
to manage the React app while [nodemon](https://nodemon.io/) works with the
backend. With containers, it's easy to separate the development needs!

## Development

To spin up the project in **development mode**, simply install Docker Desktop and then run the following
commands:

> **Important:** Docker Desktop must be running before you execute the commands below. Launch it from Applications if it's not already running.

```
git clone <your fork's clone URL>
cd <your fork's folder>
docker compose -f compose.dev.yaml up --watch
```

You'll see several container images get downloaded from Docker Hub and, after a
moment, the application will be up and running! No need to install or configure
anything on your machine!

Simply open to [http://localhost](http://localhost) to see the app up and running!

Any changes made to either the backend or frontend should be seen immediately
without needing to rebuild or restart the containers.

To help with the database, the development stack also includes phpMyAdmin, which
can be accessed at [http://db.localhost](http://db.localhost) (most browsers will
resolve `*.localhost` correctly, so no hosts file changes should be required).

### Tearing down development

When you're done, simply remove the containers by running the following command:

```
docker compose -f compose.dev.yaml down
```

---

## Production

The **production** configuration (`compose.prod.yaml`) simulates a more realistic deployment
scenario. Instead of running the frontend and backend in separate containers with live-reload
tooling, the production version bundles the compiled React frontend directly into the backend
container. This is how your app would actually run in the cloud.

### Key differences from development:

- **Single bundled image:** The frontend is pre-compiled (no Vite dev server) and served as
static assets by the backend. No live-reload or dev tooling.
- **Production-like:** Closer to how your app runs in cloud deployments (AWS, Azure,
Google Cloud, etc.).
- **Still local:** This is not a true cloud deployment — it's a local simulation using Docker Compose
to help you understand the production architecture before moving to Kubernetes.

### Running the production version

Start the production stack with:

```
docker compose -f compose.prod.yaml up
```

Open [http://localhost](http://localhost) in your browser to see the app.

The first time you run it, Docker will build the final production image (see
`Dockerfile` stage `final`). Subsequent runs will reuse the cached image, so startup
is faster.

### Tearing down production

```
docker compose -f compose.prod.yaml down
```

### When to use production

- **Testing:** Before deploying to Kubernetes (Floci EKS or a real cloud), test the
production configuration locally to catch issues early.
- **Learning:** See how the frontend and backend are packaged together in a real scenario.
- **Baseline:** Use `compose.prod.yaml` as the reference when generating Kubernetes manifests
(the K8s Floci Tutor agent can convert it for you).

---

## Next step: Kubernetes on emulated AWS

Ready to run this on Kubernetes? See the assignment in
[Floci-EKS-Assignment.md](./Floci-EKS-Assignment.md) and the step-by-step runbook in
[Floci-EKS-Kubernetes-README.md](./Floci-EKS-Kubernetes-README.md), which uses Floci
and the K8s Floci Tutor agent.
