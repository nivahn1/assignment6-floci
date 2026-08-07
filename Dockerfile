###################################################
# Stage: base
# 
# This base stage ensures all other stages are using the same base image
# and provides common configuration for all stages, such as the working dir.
###################################################
FROM node:22 AS base
WORKDIR /usr/local/app

################## CLIENT STAGES ##################

###################################################
# Stage: client-base
#
# This stage is used as the base for the client-dev and client-build stages,
# since there are common steps needed for each.
# .npmrc is an npm configuration file.  For info on npm configuration options see
# https://docs.npmjs.com/cli/v8/commands/npm-config
# npm ci is a comand for a clean install
# .eslintrc.cjs is a linter (code improver) for JavaScript and React
# vite.config.js contains configurations for the vite web build tool: https://vite.dev/
# To see the relevance of these configs, look for the scripts in package.json.
###################################################
FROM base AS client-base
COPY client/package.json client/package-lock.json ./
COPY .npmrc .
RUN npm ci
COPY client/.eslintrc.cjs client/index.html client/vite.config.js ./
COPY client/public ./public
COPY client/src ./src

###################################################
# Stage: client-dev
# 
# This stage is used for development of the client application. It sets 
# the default command to start the Vite development server.
# "dev" is defined in the scripts in package.json
# client-dev → runs the Vite dev server → serves unbundled source, 
# transformed on the fly, to your browser, with live reloading. 
# This is for the developer.
###################################################
FROM client-base AS client-dev
CMD ["npm", "run", "dev"]

###################################################
# Stage: client-build
#
# This stage builds the client application, producing static HTML, CSS, and
# JS files that can be served by the backend.
# client-build → runs npm run build → produces bundled static files in dist/, 
# which the final stage (see below) copies to the backend to serve to real end users.
###################################################
FROM client-base AS client-build
RUN npm run build


###################################################
################  BACKEND STAGES  #################
###################################################

###################################################
# Stage: sqlite3-build
#
# npm ci installs all the JS used by sqlite3 and its
# dependencies.  The ignore-scripts=true in .npmrc prevents any of
# the dependencies from having their preinstall, install, and postinstall 
# scripts run as a security measure.
# 
# Once the JS files are installed, ../bin/node-gyp does the compilation isolated from 
# the scripts in the dependencies. 
# 
# Only the compiled artifact is copied across — the scripts never land
# in any shipped image layer.
###################################################
FROM base AS sqlite3-build
COPY backend/package.json backend/package-lock.json ./
COPY .npmrc .
RUN npm ci && cd node_modules/sqlite3 && ../.bin/node-gyp rebuild

###################################################
# Stage: backend-dev
#
# This stage is used as the base for the backend-dev and test stages, since
# there are common steps needed for each.
# 
# The last 3 COPY statements should be understood:
#   The first of the 3 COPY statements copies the compiled sqlite3 image into 
#   the node_modules directory on the backend.
#   The 2nd and 3rd of the 3 COPY statements copy additional spec and src 
#   directories into their respective directories on the backend.
#
###################################################
FROM base AS backend-dev
COPY backend/package.json backend/package-lock.json ./
COPY .npmrc .
RUN npm ci
COPY --from=sqlite3-build /usr/local/app/node_modules/sqlite3/build \
    ./node_modules/sqlite3/build
COPY backend/spec ./spec
COPY backend/src ./src
CMD ["npm", "run", "dev"]

###################################################
# Stage: test
#
# This stage runs the tests on the backend. This is split into a separate
# stage to allow the final image to not have the test dependencies or test
# cases.
# The tests are found in the spec directory.
###################################################
FROM backend-dev AS test
RUN npm run test

###################################################
# Stage: final
#
# This stage is intended to be the final "production" image. It sets up the
# backend and copies the built client application from the client-build stage.
#
# It pulls the package.json and package-lock.json from the test stage to ensure that
# the tests run (without this, the test stage would simply be skipped).
###################################################
FROM base AS final
ENV NODE_ENV=production
COPY --from=test /usr/local/app/package.json /usr/local/app/package-lock.json ./
COPY .npmrc .
RUN npm ci --production && \
    npm cache clean --force
COPY --from=sqlite3-build /usr/local/app/node_modules/sqlite3/build \
    ./node_modules/sqlite3/build
COPY backend/src ./src
COPY --from=client-build /usr/local/app/dist ./src/static
EXPOSE 3000
CMD ["node", "src/index.js"]