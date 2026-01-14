# syntax=docker/dockerfile:1

# Multi-stage build for ASP.NET Core MVC app

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore as distinct layers
COPY ZavaStorefront.csproj ./
RUN dotnet restore ./ZavaStorefront.csproj

# Copy everything else and build
COPY . ./
RUN dotnet publish ./ZavaStorefront.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# App Service for Linux + containers commonly expects a known port; we standardize on 8080.
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

COPY --from=build /app/publish ./

ENTRYPOINT ["dotnet", "ZavaStorefront.dll"]
