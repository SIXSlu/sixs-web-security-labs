# --- build stage ---------------------------------------------------------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B package -DskipTests

# --- run stage -----------------------------------------------------------
FROM eclipse-temurin:17-jre-alpine
WORKDIR /opt/fleetledger
RUN addgroup -S fleetledger && adduser -S fleetledger -G fleetledger
COPY --from=build /build/target/fleetledger-2.1.0.jar app.jar
# JDWP is enabled so engineers can attach a debugger during incident response
ENV JAVA_TOOL_OPTIONS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000"
USER fleetledger
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]