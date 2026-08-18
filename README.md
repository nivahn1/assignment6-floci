# Adding Kubernetes and Minikube

This project demonstrates converting a Compose-based app to Kubernetes and running it
on a local minikube cluster. It's a stage-2 lab where students take a Docker Compose
stack, generate Kubernetes manifests, and deploy to minikube with guidance from the
K8s Local Tutor teaching agent.

## Application architecture

![Architecture diagram](./docs/architecture.png)
<!-- TODO: Update with your architecture diagram if needed -->


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

To spin up the project, simply install Docker Desktop and then run the following 
commands:

```
git clone https://bitbucket.org/txstatecs3398all/adding-kubernetes-and-minikube
cd adding-kubernetes-and-minikube
docker compose up --watch
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

### Tearing it down

When you're done, simply remove the containers by running the following command:

```
docker compose down
```
