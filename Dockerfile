FROM maven:3-jdk-8-alpine AS build
ARG NEXUS_VERSION=3.13.0
ARG NEXUS_BUILD=01

RUN wget https://github.com/sonatype-nexus-community/nexus-repository-helm/archive/v0.0.5.zip; \
    unzip v0.0.5.zip; \
	mv ./nexus-repository-helm-0.0.5 /nexus-repository-helm; \
	cd /nexus-repository-helm/; sed -i "s/3.13.0-01/${NEXUS_VERSION}-${NEXUS_BUILD}/g" pom.xml; \
    mvn clean package;

FROM quay.io/travelaudience/docker-nexus:3.13.0_alpine_3.8.1
ARG NEXUS_VERSION=3.13.0
ARG NEXUS_BUILD=01
ARG HELM_VERSION=0.0.5
ARG TARGET_DIR=/opt/sonatype/nexus/system/org/sonatype/nexus/plugins/nexus-repository-helm/${HELM_VERSION}/
USER root
RUN mkdir -p ${TARGET_DIR}; \
    sed -i 's@nexus-repository-maven</feature>@nexus-repository-maven</feature>\n        <feature prerequisite="false" dependency="false">nexus-repository-helm</feature>@g' /opt/sonatype/nexus/system/org/sonatype/nexus/assemblies/nexus-core-feature/${NEXUS_VERSION}/nexus-core-feature-${NEXUS_VERSION}-features.xml; \
    sed -i 's@<feature name="nexus-repository-maven"@<feature name="nexus-repository-helm" description="org.sonatype.nexus.plugins:nexus-repository-helm" version="0.0.5">\n        <details>org.sonatype.nexus.plugins:nexus-repository-helm</details>\n        <bundle>mvn:org.sonatype.nexus.plugins/nexus-repository-helm/0.0.5</bundle>\n        <bundle>mvn:org.apache.commons/commons-compress/1.16.1</bundle>\n   </feature>\n    <feature name="nexus-repository-maven"@g' /opt/sonatype/nexus/system/org/sonatype/nexus/assemblies/nexus-core-feature/${NEXUS_VERSION}/nexus-core-feature-${NEXUS_VERSION}-features.xml;
COPY --from=build /nexus-repository-helm/target/nexus-repository-helm-${HELM_VERSION}.jar ${TARGET_DIR}
USER nexus

