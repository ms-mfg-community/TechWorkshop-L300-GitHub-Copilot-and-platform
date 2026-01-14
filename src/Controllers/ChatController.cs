using Microsoft.AspNetCore.Mvc;
using ZavaStorefront.Models;
using ZavaStorefront.Services;

namespace ZavaStorefront.Controllers
{
    public class ChatController : Controller
    {
        private readonly ILogger<ChatController> _logger;
        private readonly ChatService _chatService;

        public ChatController(ILogger<ChatController> logger, ChatService chatService)
        {
            _logger = logger;
            _chatService = chatService;
        }

        public IActionResult Index()
        {
            _logger.LogInformation("Loading chat page");
            return View(new List<ChatMessage>());
        }

        [HttpPost]
        public async Task<IActionResult> SendMessage(string message)
        {
            if (string.IsNullOrWhiteSpace(message))
            {
                return Json(new { success = false, error = "Message cannot be empty" });
            }

            _logger.LogInformation("Sending chat message: {Message}", message);

            var response = await _chatService.SendMessageAsync(message);

            return Json(new { success = true, response = response });
        }
    }
}
