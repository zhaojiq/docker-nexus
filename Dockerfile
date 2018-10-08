FROM maven:3-jdk-8-alpine AS build
ARG NEXUS_VERSION=3.13.0
ARG NEXUS_BUILD=01

RUN wget https://github.com/sonatype-nexus-community/nexus-repository-helm/archive/v0.0.5.zip; \
    unzip v0.0.5.zip; \
	mv ./nexus-repository-helm-0.0.5 /nexus-repository-helm; \
	cd /nexus-repository-helm/; sed -i "s/3.13.0-01/${NEXUS_VERSION}-${NEXUS_BUILD}/g" pom.xml; \
    mvn clean package;

FROM quay.io/travelaudience/docker-nexus:3.13.0_alpine_3.8.1
ARG TARGET_DIR=${NEXUS_HOME}/deploy/
USER root
COPY --from=build /nexus-repository-helm/target/nexus-repository-helm-0.0.5.jar ${TARGET_DIR}
USER nexus

