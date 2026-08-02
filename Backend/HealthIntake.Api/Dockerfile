FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY HealthIntake.Api/HealthIntake.Api.csproj HealthIntake.Api/
RUN dotnet restore HealthIntake.Api/HealthIntake.Api.csproj
COPY HealthIntake.Api/ HealthIntake.Api/
RUN dotnet publish HealthIntake.Api/HealthIntake.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "HealthIntake.Api.dll"]
