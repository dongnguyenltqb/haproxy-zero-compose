FROM node:alpine
WORKDIR /app
RUN apk update && apk add curl
COPY package.json .
RUN yarn 
COPY index.js .
ENTRYPOINT [ "node","index.js" ]