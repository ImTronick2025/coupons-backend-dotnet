# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0-preview AS build
WORKDIR /src

COPY ["src/Shared/Shared.Models/Shared.Models.csproj", "Shared/Shared.Models/"]
COPY ["src/CampaignService/CampaignService/CampaignService.csproj", "CampaignService/CampaignService/"]
RUN dotnet restore "CampaignService/CampaignService/CampaignService.csproj"

COPY src/Shared/Shared.Models/ Shared/Shared.Models/
COPY src/CampaignService/CampaignService/ CampaignService/CampaignService/
WORKDIR /src/CampaignService/CampaignService
RUN dotnet build "CampaignService.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "CampaignService.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0-preview AS final
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "CampaignService.dll"]
