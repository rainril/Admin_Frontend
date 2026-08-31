# PrimeFit Chatbot NLU Service

Small Python service that classifies chatbot messages into intents
(e.g. "membership_status", "current_occupancy") and enforces
member-vs-admin permissions. Laravel calls this service, then fills
in the real data from MySQL before sending the final message to Flutter.

## Setup (Windows)

1. Make sure Python 3.10+ is installed. Check with:
   ```
   python --version
   ```
   If not installed, get it from https://www.python.org/downloads/
   (check "Add Python to PATH" during install).

2. Open a terminal in this folder and create a virtual environment:
   ```
   python -m venv venv
   venv\Scripts\activate
   ```

3. Install dependencies:
   ```
   pip install -r requirements.txt
   ```

4. Train the intent classifier (creates the `model/` folder):
   ```
   python train.py
   ```
   Re-run this any time you add more examples to `data/intents.csv`.

5. Start the service:
   ```
   uvicorn app:app --reload --port 8001
   ```
   It'll be available at `http://127.0.0.1:8001`.

6. Test it:
   ```
   curl -X POST http://127.0.0.1:8001/predict -H "Content-Type: application/json" -d "{\"text\": \"when does my membership expire\", \"role\": \"member\"}"
   ```

## Adding more training examples

Edit `data/intents.csv` — each row is `text,intent,role`. Aim for
15-20+ examples per intent for a defensible accuracy report (the
current dataset is a starter set to get the pipeline working end to
end). Re-run `python train.py` after any changes.

## Calling this from Laravel

From your Laravel backend, POST the user's message + their role
(from the authenticated session) to this service, then use the
returned `intent` to look up real data and fill the
`response_template` placeholders before sending to Flutter:

```php
// app/Services/ChatbotService.php
use Illuminate\Support\Facades\Http;

class ChatbotService
{
    public function handleMessage(string $text, string $role): string
    {
        $result = Http::post('http://127.0.0.1:8001/predict', [
            'text' => $text,
            'role' => $role,
        ])->json();

        if (!$result['allowed']) {
            return $result['response_template'];
        }

        $data = $this->fetchDataForIntent($result['intent'], $result['data_needed']);

        return strtr($result['response_template'], $this->wrapKeys($data));
    }

    private function wrapKeys(array $data): array
    {
        $wrapped = [];
        foreach ($data as $key => $value) {
            $wrapped["{" . $key . "}"] = $value;
        }
        return $wrapped;
    }

    private function fetchDataForIntent(string $intent, array $keys): array
    {
        // TODO: switch on $intent, query MySQL via your models
        // (Membership, Attendance, Billing), return an assoc array
        // matching the $keys the NLU service asked for.
        return [];
    }
}
```

## Notes for your documentation/defense

- **Why TF-IDF + Logistic Regression instead of a wrapped LLM API?**
  It's small, fast, fully explainable (you can show which words drove
  a classification), trains in seconds with no GPU, and is genuinely
  your own trained model rather than a third-party black box — much
  easier to defend to a panel as original work.
- **Why does Python not touch MySQL directly?** Clean separation of
  concerns: Python/NLU decides *what* the user is asking and *whether*
  they're allowed to ask it; Laravel owns all actual gym data. This
  also means you don't need to duplicate your Eloquent models in Python.
- **Confidence threshold**: currently tuned for a small (~65 example)
  training set. As you add more examples per intent, probability mass
  concentrates more on the correct class, so raise `CONFIDENCE_THRESHOLD`
  in `app.py` accordingly (see the comment there for how to re-tune it).
