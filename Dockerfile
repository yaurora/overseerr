FROM node:14.18-alpine AS BUILD_IMAGE

WORKDIR /app

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64} 
ENV HTTP_PROXY=
ENV HTTPS_PROXY=

RUN \
  case "${TARGETPLATFORM}" in \
    'linux/arm64' | 'linux/arm/v7') \
      apk add --no-cache python3 make g++ && \
      ln -s /usr/bin/python3 /usr/bin/python \
      ;; \
  esac

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --network-timeout 1000000

COPY . ./

ARG COMMIT_TAG
ENV COMMIT_TAG=${COMMIT_TAG}

RUN yarn build

# remove development dependencies
RUN yarn install --production --ignore-scripts --prefer-offline

RUN rm -rf src server

RUN touch config/DOCKER

RUN echo "{\"commitTag\": \"${COMMIT_TAG}\"}" > committag.json


FROM node:14.18-alpine

WORKDIR /app

RUN apk add --no-cache tzdata tini

# copy from build image
COPY --from=BUILD_IMAGE /app ./

ENTRYPOINT [ "/sbin/tini", "--" ]
RUN yarn config set httpProxy $HTTP_PROXY && yarn config set httpsProxy $HTTPS_PROXY
CMD [ "yarn", "start" ]

EXPOSE 5055
