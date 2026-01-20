# Zava Storefront - ASP.NET Core MVC

A simple e-commerce storefront application built with .NET 8 ASP.NET MVC.

## Features

- **Product Listing**: Browse a catalog of 8 sample products with images, descriptions, and prices
- **Shopping Cart**: Add products to cart with session-based storage
- **Cart Management**: View cart, update quantities, remove items
- **Checkout**: Simple checkout process that clears cart and shows success message
- **AI Chat**: Interactive chat powered by Microsoft Foundry Phi-4 endpoint
- **Responsive Design**: Mobile-friendly layout using Bootstrap 5

## Technology Stack

- .NET 8 (LTS)
- ASP.NET Core MVC
- Bootstrap 5
- Bootstrap Icons
- Session-based state management (no database)
- Microsoft Foundry (Azure AI Services) with Phi-4 model

## Project Structure

```
ZavaStorefront/
├── Controllers/
│   ├── HomeController.cs      # Products listing and add to cart
│   ├── CartController.cs       # Cart operations and checkout
│   └── ChatController.cs       # AI chat functionality
├── Models/
│   ├── Product.cs              # Product model
│   ├── CartItem.cs             # Cart item model
│   └── ChatMessage.cs          # Chat message model
├── Services/
│   ├── ProductService.cs       # Static product data
│   ├── CartService.cs          # Session-based cart management
│   └── ChatService.cs          # Foundry Phi-4 integration
├── Views/
│   ├── Home/
│   │   └── Index.cshtml        # Products listing page
│   ├── Cart/
│   │   ├── Index.cshtml        # Shopping cart page
│   │   └── CheckoutSuccess.cshtml  # Checkout success page
│   ├── Chat/
│   │   └── Index.cshtml        # AI chat interface
│   └── Shared/
│       └── _Layout.cshtml      # Main layout with cart icon
└── wwwroot/
    ├── css/
    │   └── site.css            # Custom styles
    └── images/
        └── products/           # Product images directory
```

## How to Run

1. Navigate to the project directory:
   ```bash
   cd ZavaStorefront
   ```

2. Run the application:
   ```bash
   dotnet run
   ```

3. Open your browser and navigate to:
   ```
   https://localhost:5001
   ```

## AI Chat Configuration

The chat feature requires configuration of the Microsoft Foundry Phi-4 endpoint. You have three options for configuration:

### Option 1: User Secrets (Recommended for Development)

Use .NET user secrets to store sensitive configuration:

```bash
cd ZavaStorefront
dotnet user-secrets set "FoundryPhi4:Endpoint" "https://your-foundry-resource.openai.azure.com"
dotnet user-secrets set "FoundryPhi4:ApiKey" "your-api-key-here"
dotnet user-secrets set "FoundryPhi4:DeploymentName" "phi-4"
```

### Option 2: appsettings.Development.json

Create an `appsettings.Development.json` file (DO NOT commit this to source control):

```json
{
  "FoundryPhi4": {
    "Endpoint": "https://your-foundry-resource.openai.azure.com",
    "ApiKey": "your-api-key-here",
    "DeploymentName": "phi-4"
  }
}
```

### Option 3: Environment Variables

Set environment variables:

```bash
export FoundryPhi4__Endpoint="https://your-foundry-resource.openai.azure.com"
export FoundryPhi4__ApiKey="your-api-key-here"
export FoundryPhi4__DeploymentName="phi-4"
```

### Getting Your Foundry Endpoint and API Key

After deploying the infrastructure with `enableAi = true`:

1. Go to Azure Portal
2. Navigate to your resource group
3. Find the AI Services resource (named like `ai-zava-dev-xxxxx`)
4. Go to "Keys and Endpoint" section
5. Copy the endpoint URL and one of the API keys
6. The deployment name should match your Phi-4 model deployment (default: "phi-4")

## Product Images

The application includes 8 sample products. Product images are referenced from:
- `/wwwroot/images/products/`

If images are not found, the application automatically falls back to placeholder images from placeholder.com.

To add custom product images, place JPG files in `wwwroot/images/products/` with these names:
- headphones.jpg
- smartwatch.jpg
- speaker.jpg
- charger.jpg
- usb-hub.jpg
- keyboard.jpg
- mouse.jpg
- webcam.jpg

## Sample Products

1. Wireless Bluetooth Headphones - $89.99
2. Smart Fitness Watch - $199.99
3. Portable Bluetooth Speaker - $49.99
4. Wireless Charging Pad - $29.99
5. USB-C Hub Adapter - $39.99
6. Mechanical Gaming Keyboard - $119.99
7. Ergonomic Wireless Mouse - $34.99
8. HD Webcam - $69.99

## Application Flow

1. **Landing Page**: Displays all products in a responsive grid
2. **Add to Cart**: Click "Buy" button to add products to cart
3. **View Cart**: Click cart icon (top right) to view cart contents
4. **Update Cart**: Modify quantities or remove items
5. **Checkout**: Click "Checkout" button to complete purchase
6. **Success**: View confirmation and return to products
7. **Chat**: Click "Chat" in navigation to interact with AI assistant

## Session Management

- Cart data is stored in session
- Session timeout: 30 minutes
- No data persistence (cart clears when session expires)
- Cart is cleared after successful checkout

## Logging

The application includes structured logging for:
- Product page loads
- Adding products to cart
- Cart operations (update, remove)
- Checkout process
- Chat message sending and responses

Logs are written to console during development.
