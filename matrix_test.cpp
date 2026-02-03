#include <iostream>
#include <iomanip>
#include <string>
#include <vector>
#include <map>
#include <curl/curl.h>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

// === Helper: collect HTTP response ===
static size_t WriteCallback(void* contents, size_t size, size_t nmemb, std::string* output) {
    size_t totalSize = size * nmemb;
    output->append((char*)contents, totalSize);
    return totalSize;
}

int main() {
    // === Define locations ===
    std::map<std::string, std::pair<double, double>> locations = {
        {"Vancouver", {-123.1207, 49.2827}},
        {"Kitsilano", {-123.1162, 49.2463}},
        {"Surrey", {-122.8490, 49.1913}},
        {"Burnaby", {-122.9820, 49.2488}}
    };

    // === Build JSON payload ===
    json payload;
    for (auto& [name, coord] : locations)
        payload["coordinates"].push_back({coord.first, coord.second});

    // === Setup libcurl ===
    CURL* curl = curl_easy_init();
    std::string readBuffer;
    if (curl) {
        curl_easy_setopt(curl, CURLOPT_URL, "http://localhost:8080/matrix");
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, payload.dump().c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, payload.dump().size());
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);

        struct curl_slist* headers = nullptr;
        headers = curl_slist_append(headers, "Content-Type: application/json");
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

        CURLcode res = curl_easy_perform(curl);
        curl_easy_cleanup(curl);
        curl_slist_free_all(headers);

        if (res != CURLE_OK) {
            std::cerr << "❌ Request failed: " << curl_easy_strerror(res) << "\n";
            return 1;
        }
    } else {
        std::cerr << "❌ Could not init CURL\n";
        return 1;
    }

    // === Parse JSON ===
    json response = json::parse(readBuffer);
    auto dist = response["distance_matrix"];
    auto dur = response["duration_matrix"];

    std::vector<std::string> names;
    for (auto& [name, _] : locations) names.push_back(name);

    // === Print Distance Matrix (km) ===
    std::cout << "\n🚗 Distance Matrix (km):\n\n";
    std::cout << std::fixed << std::setprecision(2);
    std::cout << std::setw(12) << "";
    for (const auto& col : names)
        std::cout << std::setw(12) << col;
    std::cout << "\n";

    for (size_t i = 0; i < names.size(); ++i) {
        std::cout << std::setw(12) << names[i];
        for (size_t j = 0; j < names.size(); ++j) {
            std::cout << std::setw(12) << dist[i][j].get<double>() / 1000.0;
        }
        std::cout << "\n";
    }

    // === Print Duration Matrix (min) ===
    std::cout << "\n⏱️ Duration Matrix (min):\n\n";
    std::cout << std::setw(12) << "";
    for (const auto& col : names)
        std::cout << std::setw(12) << col;
    std::cout << "\n";

    for (size_t i = 0; i < names.size(); ++i) {
        std::cout << std::setw(12) << names[i];
        for (size_t j = 0; j < names.size(); ++j) {
            std::cout << std::setw(12) << dur[i][j].get<double>() / 60.0;
        }
        std::cout << "\n";
    }

    return 0;
}
