using System.Text;
using System.Text.Json;
using ZavaStorefront.Models;

namespace ZavaStorefront.Services
{
    public class ChatService
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger<ChatService> _logger;
        private readonly IConfiguration _configuration;

        public ChatService(HttpClient httpClient, ILogger<ChatService> logger, IConfiguration configuration)
        {
            _httpClient = httpClient;
            _logger = logger;
            _configuration = configuration;
        }

        public async Task<string> SendMessageAsync(string userMessage)
        {
            try
            {
                var endpoint = _configuration["FoundryPhi4:Endpoint"];
                var apiKey = _configuration["FoundryPhi4:ApiKey"];
                var deploymentName = _configuration["FoundryPhi4:DeploymentName"] ?? "phi-4";

                if (string.IsNullOrEmpty(endpoint))
                {
                    _logger.LogWarning("Foundry Phi-4 endpoint not configured");
                    return "Chat service is not configured. Please set the FoundryPhi4:Endpoint configuration.";
                }

                if (string.IsNullOrEmpty(apiKey))
                {
                    _logger.LogWarning("Foundry Phi-4 API key not configured");
                    return "Chat service is not configured. Please set the FoundryPhi4:ApiKey configuration.";
                }

                // Construct the full URL
                var url = $"{endpoint.TrimEnd('/')}/openai/deployments/{deploymentName}/chat/completions?api-version=2024-02-15-preview";

                var requestBody = new
                {
                    messages = new[]
                    {
                        new { role = "system", content = "You are a helpful AI assistant for the Zava Storefront." },
                        new { role = "user", content = userMessage }
                    },
                    max_tokens = 500,
                    temperature = 0.7
                };

                var json = JsonSerializer.Serialize(requestBody);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                _httpClient.DefaultRequestHeaders.Clear();
                _httpClient.DefaultRequestHeaders.Add("api-key", apiKey);

                _logger.LogInformation("Sending message to Foundry Phi-4 endpoint: {Url}", url);

                var response = await _httpClient.PostAsync(url, content);
                var responseContent = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogError("Failed to get response from Foundry Phi-4. Status: {StatusCode}, Response: {Response}", 
                        response.StatusCode, responseContent);
                    return $"Error: Unable to get response from chat service. Status: {response.StatusCode}";
                }

                var responseJson = JsonDocument.Parse(responseContent);
                var choices = responseJson.RootElement.GetProperty("choices");
                if (choices.GetArrayLength() > 0)
                {
                    var message = choices[0].GetProperty("message").GetProperty("content").GetString();
                    return message ?? "No response received.";
                }

                return "No response received from the chat service.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error sending message to Foundry Phi-4");
                return $"Error: {ex.Message}";
            }
        }
    }
}
