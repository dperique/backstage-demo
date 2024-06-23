# Stage 1: Install yarn, and prepare the build environment
FROM node:18-bookworm-slim AS build-env

# Install necessary build dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends python3 g++ build-essential git && \
    yarn set version 1.x

# Set the working directory
WORKDIR /app

RUN echo "Current version of @backstage/create-app:" && npm show @backstage/create-app version

# Create the Backstage application using a specific version
# since we have to fixup one of the source files (App.tsx)
RUN BACKSTAGE_APP_NAME=build-backstage npx @backstage/create-app@0.5.16

# Change to the build-backstage directory
WORKDIR /app/build-backstage

COPY dot_gitignore .gitignore
RUN git config --global user.email "none@none.com" && git config --global user.name "none none"
RUN git config --global init.defaultBranch main
RUN git init . && git add . && git commit -m "Initial commit"

# Copy over our custom config files and remove the SignInPage dialog from App.tsx
COPY app-config.yaml catalog-info.yaml ./
RUN sed -i '/SignInPage/d' packages/app/src/App.tsx

# Install dependencies and build the project
RUN yarn install && \
    yarn tsc && \
    yarn build:backend --config ../../app-config.yaml

# Stage 2: Create the final image
FROM node:18-bookworm-slim

ARG VERSION

# Install isolate-vm dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends python3 g++ build-essential && \
    yarn config set python /usr/bin/python3

# Install sqlite3 dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends libsqlite3-dev

# From here on we use the least-privileged `node` user to run the backend.
USER node

# Set the working directory
WORKDIR /app

# This switches many Node.js dependencies to production mode.
ENV NODE_ENV production

# Copy the built artifacts from the build stage
COPY --from=build-env --chown=node:node /app/build-backstage/yarn.lock ./
COPY --from=build-env --chown=node:node /app/build-backstage/package.json ./
COPY --from=build-env --chown=node:node /app/build-backstage/app-config*.yaml ./
COPY --from=build-env --chown=node:node /app/build-backstage/catalog-info.yaml ./
COPY --from=build-env --chown=node:node /app/build-backstage/packages ./packages

# Copy repo skeleton first, to avoid unnecessary docker cache invalidation.
# The skeleton contains the package.json of each package in the monorepo,
# and along with yarn.lock and the root package.json, that's enough to run yarn install.
COPY --from=build-env --chown=node:node /app/build-backstage/packages/backend/dist/skeleton.tar.gz ./
RUN tar xzf skeleton.tar.gz && rm skeleton.tar.gz

# Then copy the rest of the backend bundle, along with any other files we might want.
RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn install --frozen-lockfile --production --network-timeout 300000

# Extract the built backend bundle
COPY --from=build-env --chown=node:node /app/build-backstage/packages/backend/dist/bundle.tar.gz ./
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

COPY --from=build-env --chown=node:node /app/build-backstage/catalog-info.yaml catalog-info.yaml

# Drop a version to help distinguish between different builds
RUN echo "$VERSION" > VERSION

# Set the log level environment variable
ENV LOG_LEVEL debug

# Set the command to run the backend
CMD ["node", "packages/backend", "--config", "app-config.yaml"]
