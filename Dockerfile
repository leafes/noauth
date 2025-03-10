# Stage 1: Build
FROM node:22.7-alpine AS build

# Lock environment for reproducibility
ARG SOURCE_DATE_EPOCH=1700000000
ENV TZ=UTC
WORKDIR /usr/src/app

# Install essential build tools
RUN apk add --no-cache python3 make g++

# Copy only package-related files first (to leverage Docker cache)
COPY lerna.json ./
COPY package*.json ./
COPY packages/client/package*.json ./packages/client/
COPY packages/common/package*.json ./packages/common/
COPY packages/backend/package*.json ./packages/backend/
COPY packages/server/package*.json ./packages/server/

# Install dependencies in a deterministic way
RUN npm ci --ignore-scripts

# Copy the rest of the project
COPY . .

# Set timestamp for deterministic builds
RUN find . -exec touch -t 200001010000 {} +

# Build project
RUN npm run build

# Stage 2: Client (Nginx)
FROM nginx:alpine AS client
WORKDIR /usr/share/nginx/html

# Copy built client assets with preserved permissions
COPY --from=build /usr/src/app/packages/client/build ./
COPY packages/client/nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Run Nginx
CMD ["nginx", "-g", "daemon off;"]

# Stage 3: Server (Node.js)
FROM node:22.7-alpine AS server
WORKDIR /usr/src/app

# Copy only built files and necessary dependencies
COPY --from=build /usr/src/app ./

# Ensure Prisma migrations are applied
RUN npx prisma migrate deploy

# Expose the required port
EXPOSE 8080

# Run the server
# CMD ["npm", "run", "start:server"]