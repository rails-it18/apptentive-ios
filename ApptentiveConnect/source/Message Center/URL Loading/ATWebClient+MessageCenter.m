//
//  ATWebClient+MessageCenter.m
//  ApptentiveConnect
//
//  Created by Andrew Wooster on 10/2/12.
//  Copyright (c) 2012 Apptentive, Inc. All rights reserved.
//

#import "ATWebClient+MessageCenter.h"

#import "ATAPIRequest.h"
#import "ATBackend.h"
#import "ATFileMessage.h"
#import "ATFileAttachment.h"
#import "ATURLConnection.h"
#import "ATWebClient_Private.h"

#import "PJSONKit.h"

#define kMessageCenterChannelName (@"Message Center")

@implementation ATWebClient (MessageCenter)
- (ATAPIRequest *)requestForCreatingConversation:(ATConversation *)conversation {
	NSError *error = nil;
	NSDictionary *postJSON = nil;
	if (conversation == nil) {
		postJSON = [NSDictionary dictionary];
	} else {
		postJSON = [conversation apiJSON];
	}
	NSString *postString = [postJSON ATJSONStringWithOptions:ATJKSerializeOptionPretty error:&error];
	if (!postString && error != nil) {
		ATLogError(@"Error while encoding JSON: %@", error);
		return nil;
	}
	NSString *url = [self apiURLStringWithPath:@"conversation"];
	ATURLConnection *conn = nil;
	
	conn = [self connectionToPost:[NSURL URLWithString:url] JSON:postString];
	
	conn.timeoutInterval = 60.0;
	ATAPIRequest *request = [[ATAPIRequest alloc] initWithConnection:conn channelName:kMessageCenterChannelName];
	request.returnType = ATAPIRequestReturnTypeJSON;
	return [request autorelease];
}

- (ATAPIRequest *)requestForUpdatingDevice:(ATDeviceInfo *)deviceInfo {
	NSError *error = nil;
	NSDictionary *postJSON = [deviceInfo apiJSON];
	
	NSString *postString = [postJSON ATJSONStringWithOptions:ATJKSerializeOptionPretty error:&error];
	if (!postString && error != nil) {
		ATLogError(@"Error while encoding JSON: %@", error);
		return nil;
	}
	
	ATConversation *conversation = [ATConversationUpdater currentConversation];
	if (!conversation) {
		ATLogError(@"No current conversation.");
		return nil;
	}
	
	NSString *url = [self apiURLStringWithPath:@"devices"];
	
	ATURLConnection *conn = [self connectionToPut:[NSURL URLWithString:url] JSON:postString];
	conn.timeoutInterval = 60.0;
	[self updateConnection:conn withOAuthToken:conversation.token];
	ATAPIRequest *request = [[ATAPIRequest alloc] initWithConnection:conn channelName:kMessageCenterChannelName];
	request.returnType = ATAPIRequestReturnTypeJSON;
	return [request autorelease];
}

- (ATAPIRequest *)requestForPostingMessage:(ATMessage *)message {
	NSError *error = nil;
	NSDictionary *messageJSON = [message apiJSON];
	NSDictionary *postJSON = nil;
	if ([message isKindOfClass:[ATFileMessage class]]) {
		postJSON = messageJSON;
	} else {
		postJSON = @{@"message":messageJSON};
	}
	
	NSString *postString = [postJSON ATJSONStringWithOptions:ATJKSerializeOptionPretty error:&error];
	if (!postString && error != nil) {
		ATLogError(@"Error while encoding JSON: %@", error);
		return nil;
	}
	
	ATConversation *conversation = [ATConversationUpdater currentConversation];
	if (!conversation) {
		ATLogError(@"No current conversation");
		return nil;
	}
	NSString *path = @"messages";
	NSString *urlString = [self apiURLStringWithPath:path];
	
	ATURLConnection *conn = nil;
	NSURL *url = [NSURL URLWithString:urlString];
	
	if ([message isKindOfClass:[ATFileMessage class]]) {
		ATFileMessage *fileMessage = (ATFileMessage *)message;
		ATFileAttachment *fileAttachment = fileMessage.fileAttachment;
		if (!fileAttachment) {
			ATLogError(@"Expected file attachment on message");
			return nil;
		}
		conn = [self connectionToPost:url JSON:postString withFile:[fileAttachment fullLocalPath] ofMimeType:fileAttachment.mimeType];
	} else {
		conn = [self connectionToPost:url JSON:postString];
	}
	conn.timeoutInterval = 60.0;
	[self updateConnection:conn withOAuthToken:conversation.token];
	ATAPIRequest *request = [[ATAPIRequest alloc] initWithConnection:conn channelName:kMessageCenterChannelName];
	request.returnType = ATAPIRequestReturnTypeJSON;
	return [request autorelease];
}

- (ATAPIRequest *)requestForRetrievingMessagesSinceMessage:(ATMessage *)message {
	NSDictionary *parameters = nil;
	if (message && message.apptentiveID) {
		parameters = @{@"after_id":message.apptentiveID};
	}
	
	ATConversation *conversation = [ATConversationUpdater currentConversation];
	if (!conversation) {
		NSLog(@"No current conversation.");
		return nil;
	}
	
	NSString *path = @"conversation";
	if (parameters) {
		NSString *paramString = [self stringForParameters:parameters];
		path = [NSString stringWithFormat:@"%@?%@", path, paramString];
	}
	NSString *url = [self apiURLStringWithPath:path];
	
	ATURLConnection *conn = [self connectionToGet:[NSURL URLWithString:url]];
	conn.timeoutInterval = 60.0;
	[self updateConnection:conn withOAuthToken:conversation.token];
	ATAPIRequest *request = [[ATAPIRequest alloc] initWithConnection:conn channelName:kMessageCenterChannelName];
	request.returnType = ATAPIRequestReturnTypeJSON;
	return [request autorelease];
}
@end