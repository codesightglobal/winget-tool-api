FROM node:20-alpine

# Install git
RUN apk add --no-cache git

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY . .

RUN npm run build

EXPOSE 4000

CMD ["node", "dist/app.js"]
