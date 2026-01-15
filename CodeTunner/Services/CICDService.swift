import Foundation

struct WorkflowRun: Codable, Identifiable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let html_url: String
    let created_at: String
    let display_title: String
    let run_number: Int
    
    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, html_url, created_at, display_title, run_number
    }
}

struct WorkflowRunsResponse: Codable {
    let workflow_runs: [WorkflowRun]
    let total_count: Int
}

struct Step: Codable, Identifiable {
    var id: String { name + String(number) } // Steps don't always have IDs from GitHub, so composite
    let name: String
    let status: String
    let conclusion: String?
    let number: Int
    
    enum CodingKeys: String, CodingKey {
        case name, status, conclusion, number
    }
}

struct Job: Codable, Identifiable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let html_url: String
    let steps: [Step]?
}

struct JobsResponse: Codable {
    let jobs: [Job]
}

class CICDService: ObservableObject {
    static let shared = CICDService()
    private let baseURL = "http://127.0.0.1:3000/api/cicd"
    
    func fetchWorkflowRuns(owner: String, repo: String, token: String, completion: @escaping (Result<[WorkflowRun], Error>) -> Void) {
        let url = URL(string: "\(baseURL)/runs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "owner": owner,
            "repo": repo,
            "token": token
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(WorkflowRunsResponse.self, from: data)
                completion(.success(response.workflow_runs))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func fetchJobs(owner: String, repo: String, token: String, runId: Int, completion: @escaping (Result<[Job], Error>) -> Void) {
        let url = URL(string: "\(baseURL)/jobs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "owner": owner,
            "repo": repo,
            "token": token,
            "run_id": runId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(JobsResponse.self, from: data)
                completion(.success(response.jobs))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func triggerWorkflow(owner: String, repo: String, token: String, workflowId: String, ref: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/trigger")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "owner": owner,
            "repo": repo,
            "token": token,
            "workflow_id": workflowId,
            "ref_name": ref
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            // Check 200 OK
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                completion(.success(true))
            } else {
                completion(.success(false))
            }
        }.resume()
    }
    
    func getJobLogs(owner: String, repo: String, token: String, jobId: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "\(baseURL)/logs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "owner": owner,
            "repo": repo,
            "token": token,
            "job_id": jobId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                // Expecting { "logs": "..." }
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let logs = json["logs"] as? String {
                    completion(.success(logs))
                } else {
                    completion(.failure(NSError(domain: "CICD", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid format"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
