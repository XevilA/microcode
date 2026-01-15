//
//  AuthenticSyntaxEngine.mm
//  CodeTunner
//
//  Created by SPU AI CLUB
//  Copyright © 2026 AIPRENEUR. All rights reserved.
//

#import "AuthenticSyntaxEngine.h"
#include <string>
#include <vector>
#include <unordered_set>
#include <unordered_map>
#include <iostream>
#include <exception>

// MARK: - AuthenticToken Implementation

@implementation AuthenticToken
+ (instancetype)tokenWithType:(AuthenticTokenType)type range:(NSRange)range content:(NSString *)content {
    AuthenticToken *token = [[AuthenticToken alloc] init];
    token.type = type;
    token.range = range;
    token.content = content;
    return token;
}
@end

// MARK: - C++ Core Lexer

namespace MicroLexer {
    
    enum class State {
        Normal,
        InStringDouble,
        InStringSingle,
        InCommentLine,
        InCommentBlock
    };

    struct Token {
        AuthenticTokenType type;
        size_t start;
        size_t length;
    };

    class Engine {
    public:
        std::unordered_set<std::string> keywords;
        std::unordered_set<std::string> declarationKeywords;
        
        Engine(const std::string& lang) {
            if (lang == "swift") {
                keywords = {"if", "else", "return", "import", "extension", "guard", "switch", "case", "try", "catch"};
                declarationKeywords = {"func", "var", "let", "class", "struct", "enum", "protocol", "public", "private"};
            } else if (lang == "python") {
                keywords = {"return", "if", "else", "elif", "for", "while", "import", "from", "as", "try", "except", "pass", "None", "True", "False"};
                declarationKeywords = {"def", "class"};
            } else {
                keywords = {"return", "if", "else", "for", "while", "using", "include"};
                declarationKeywords = {"int", "float", "double", "char", "void", "class", "struct", "public", "private", "protected", "namespace"};
            }
        }
        
        std::vector<Token> tokenize(const std::string& source) {
            std::vector<Token> tokens;
            size_t i = 0;
            size_t len = source.length();
            
            while (i < len) {
                char c = source[i];
                
                // Whitespace
                if (isspace(c)) {
                    i++;
                    continue;
                }
                
                // Strings
                if (c == '"' || c == '\'') {
                    size_t start = i;
                    char quote = c;
                    i++;
                    while (i < len && source[i] != quote) {
                        if (source[i] == '\\' && i + 1 < len) i++; // Skip escape
                        i++;
                    }
                    if (i < len) i++; // Consume closing quote
                    tokens.push_back({AuthenticTokenTypeString, start, i - start});
                    continue;
                }
                
                // Comments (Line) //
                if (c == '/' && i + 1 < len && source[i+1] == '/') {
                    size_t start = i;
                    while (i < len && source[i] != '\n') {
                        i++;
                    }
                    tokens.push_back({AuthenticTokenTypeComment, start, i - start});
                    continue;
                }
                
                // Numbers
                if (isdigit(c)) {
                    size_t start = i;
                    while (i < len && (isdigit(source[i]) || source[i] == '.')) {
                        i++;
                    }
                    tokens.push_back({AuthenticTokenTypeNumber, start, i - start});
                    continue;
                }
                
                // Identifiers / Keywords
                if (isalpha(c) || c == '_') {
                    size_t start = i;
                    while (i < len && (isalnum(source[i]) || source[i] == '_')) {
                        i++;
                    }
                    std::string word = source.substr(start, i - start);
                    
                    if (declarationKeywords.count(word)) {
                        tokens.push_back({AuthenticTokenTypeKeywordDeclaration, start, i - start});
                    } else if (keywords.count(word)) {
                        tokens.push_back({AuthenticTokenTypeKeyword, start, i - start});
                    } else {
                        // Heuristic for types (start with uppercase)
                        if (isupper(word[0])) {
                            tokens.push_back({AuthenticTokenTypeType, start, i - start});
                        } else {
                             // Check for function call
                            size_t nextC = i;
                            while(nextC < len && isspace(source[nextC])) nextC++;
                            if(nextC < len && source[nextC] == '(') {
                                tokens.push_back({AuthenticTokenTypeFunction, start, i - start});
                            } else {
                                tokens.push_back({AuthenticTokenTypeIdentifier, start, i - start});
                            }
                        }
                    }
                    continue;
                }
                
                // Operators / Punctuation
                if (ispunct(c)) {
                    tokens.push_back({AuthenticTokenTypePunctuation, i, 1});
                    i++;
                    continue;
                }
                
                i++; // Fallback
            }
            return tokens;
        }
    };
}

// MARK: - AuthenticSyntaxEngine Implementation

@implementation AuthenticSyntaxEngine

+ (NSArray<AuthenticToken *> *)tokenizeSource:(NSString *)source language:(NSString *)language {
    // 1. Initial nil/empty check
    if (!source || source.length == 0) return @[];
    
    // 2. Safe encoding conversion
    const char *utf8Source = [source UTF8String];
    const char *utf8Lang = [language UTF8String];
    
    // 3. NULL check for UTF8String (can return NULL for encoding errors)
    if (!utf8Source) {
        NSLog(@"[AuthenticSyntaxEngine] Error: source UTF8String is NULL");
        return @[];
    }
    if (!utf8Lang) {
        // Fallback to "text" or safe default if language name is weird
        utf8Lang = "text";
    }
    
    try {
        // 4. Construct std::string safely
        std::string cppSource(utf8Source);
        std::string cppLang(utf8Lang);
        
        MicroLexer::Engine engine(cppLang);
        std::vector<MicroLexer::Token> cppTokens = engine.tokenize(cppSource);
        
        NSMutableArray<AuthenticToken *> *result = [NSMutableArray arrayWithCapacity:cppTokens.size()];
        
        NSUInteger sourceLength = source.length;
        
        for (const auto& t : cppTokens) {
            // 5. Range Safety Check
            // Verify that byte offsets don't exceed source bounds
            // Note: This matches byte length, but NSString expects unicode char indices.
            // For now, we perform a basic clamp to prevent NSRangeException.
            // TODO: Proper byte-to-char index mapping.
            
            if (t.start >= sourceLength) continue;
            
            NSUInteger length = t.length;
            if (t.start + length > sourceLength) {
                length = sourceLength - t.start;
            }
            
            if (length == 0) continue;
            
            NSRange range = NSMakeRange(t.start, length);
            
            // Optimization: Pass empty content string as we only need the range/type in the editor
            [result addObject:[AuthenticToken tokenWithType:t.type range:range content:@""]];
        }
        
        return result;
        
    } catch (const std::exception& e) {
        NSLog(@"[AuthenticSyntaxEngine] C++ Exception: %s", e.what());
        return @[];
    } catch (...) {
        NSLog(@"[AuthenticSyntaxEngine] Unknown C++ Exception");
        return @[];
    }
}

+ (NSArray<AuthenticToken *> *)tokenizeLine:(NSString *)line language:(NSString *)language startState:(NSInteger)startState endState:(NSInteger *)endState {
    // TODO: Implement state-aware line tokenization for scroll perf
    return [self tokenizeSource:line language:language];
}

@end
