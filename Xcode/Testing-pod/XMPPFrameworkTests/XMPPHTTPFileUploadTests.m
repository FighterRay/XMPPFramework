//
//  XMPPHTTPFileUploadTests.m
//  XMPPFrameworkTests
//
//  Created by Andres on 5/23/16.
//
//

#import <XCTest/XCTest.h>
#import "XMPPFramework/XMPPSlot.h"
#import "XMPPFramework/XMPPHTTPFileUpload.h"
#import "XMPPFramework/XMPPStream.h"
#import "XMPPMockStream.h"

@interface XMPPHTTPFileUploadTests: XCTestCase
@property (nonatomic, strong) XCTestExpectation *slotResponseExpectation;
@end

@implementation XMPPHTTPFileUploadTests

- (void)setUp {
	[super setUp];
}

- (void)tearDown {
	[super tearDown];
}

- (void) testSlotInitWithIQ {
	NSMutableString *s = [NSMutableString string];
	[s appendString:@"<iq from='upload.montague.tld' id='step_03' to='romeo@montague.tld/garden' type='result'>"];
	[s appendString:@"  <slot xmlns='urn:xmpp:http:upload'>"];
	[s appendString:@"    <put>http://put.com</put>"];
	[s appendString:@"	  <get>http://get.com</get>"];
	[s appendString:@"  </slot>"];
	[s appendString:@"</iq>"];
	
	NSError *error;
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	
	XMPPSlot *slot = [[XMPPSlot alloc] initWithIQ:iq];
	
	XCTAssertNil(error);
	XCTAssertEqualObjects(slot.get, @"http://get.com");
	XCTAssertEqualObjects(slot.put, @"http://put.com");
}

- (void) testSlotInit {
	
	XMPPSlot *slot = [[XMPPSlot alloc] initWithGet:@"http://put.com" andGet:@"http://get.com"];

	XCTAssertEqualObjects(slot.get, @"http://get.com");
	XCTAssertEqualObjects(slot.put, @"http://put.com");
}

- (void) testRequestSlot {
	XCTestExpectation *expectation = [self expectationWithDescription:@"Handler IQ"];
	
	// From XEP-0363, Section 4. Requesting a slot
	
	NSMutableString *s = [NSMutableString string];
	[s appendString:@"<iq id='testid' to='upload.montague.tld' type='get'>"];
	[s appendString:@"  <request xmlns='urn:xmpp:http:upload'>"];
	[s appendString:@"		<filename>my_juliet.png</filename>"];
	[s appendString:@"		<size>23456</size>"];
	[s appendString:@"		<content-type>image/jpeg</content-type>"];
	[s appendString:@"  </request>"];
	[s appendString:@"</iq>"];
	
	NSError *error;
	
	NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:s options:0 error:&error];
	XMPPIQ *iq = [XMPPIQ iqFromElement:[doc rootElement]];
	
	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		XMPPIQ *sentIQ = [XMPPIQ iqFromElement:element];
		
		XCTAssertEqualObjects(sentIQ.type, iq.type);
		XCTAssertEqualObjects(sentIQ.to, iq.to);
		
		NSXMLElement *sentRequest = [sentIQ childElement];
		NSXMLElement *request = [iq childElement];
		
		XCTAssertEqualObjects(sentRequest.xmlns, @"urn:xmpp:http:upload");
		XCTAssertEqualObjects(sentRequest.xmlns, request.xmlns);
		
		NSString *filename = [sentRequest elementForName:@"filename"].stringValue;
		NSString *size = [sentRequest elementForName:@"size"].stringValue;
		NSString *contentType = [sentRequest elementForName:@"content-type"].stringValue;
		
		XCTAssertEqualObjects(filename, @"my_juliet.png");
		XCTAssertEqualObjects(size, @"23456");
		XCTAssertEqualObjects(contentType, @"image/jpeg");
		
		[expectation fulfill];
	};
	
	XMPPHTTPFileUpload *xmppFileUpload = [[XMPPHTTPFileUpload alloc] initWithServiceName:@"upload.montague.tld"];
	[xmppFileUpload activate:streamTest];
	[xmppFileUpload requestSlotForFile:@"my_juliet.png" size:23456 contentType:@"image/jpeg"];

	[self waitForExpectationsWithTimeout:1 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];

	XCTAssertNil(error);
}

- (void) testResponseSlot {
	self.slotResponseExpectation = [self expectationWithDescription:@"Slot Response"];

	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPHTTPFileUpload *xmppFileUpload = [[XMPPHTTPFileUpload alloc] initWithServiceName:@"upload.montague.tld"];
	[xmppFileUpload activate:streamTest];
	[xmppFileUpload addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self responseSuccessIQWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};

	[xmppFileUpload requestSlotForFile:@"my_juliet.png" size:23456 contentType:@"image/jpeg"];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void) testResponseSlotWithError {
	self.slotResponseExpectation = [self expectationWithDescription:@"Slot Response"];
	
	XMPPMockStream *streamTest = [[XMPPMockStream alloc] init];
	XMPPHTTPFileUpload *xmppFileUpload = [[XMPPHTTPFileUpload alloc] initWithServiceName:@"upload.montague.tld"];
	[xmppFileUpload activate:streamTest];
	[xmppFileUpload addDelegate:self delegateQueue:dispatch_get_main_queue()];
	
	__weak typeof(XMPPMockStream) *weakStreamTest = streamTest;
	streamTest.elementReceived = ^void(NSXMLElement *element) {
		NSString *elementID = [element attributeForName:@"id"].stringValue;
		XMPPIQ *iq = [self responseErrorIQWithID:elementID];
		[weakStreamTest fakeIQResponse:iq];
	};
	
	[xmppFileUpload requestSlotForFile:@"my_juliet.png" size:23456 contentType:@"image/jpeg"];
	
	[self waitForExpectationsWithTimeout:10 handler:^(NSError * _Nullable error) {
		if(error){
			XCTFail(@"Expectation Failed with error: %@", error);
		}
	}];
}

- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender didAssignSlot:(XMPPSlot *)slot {
	XCTAssertEqualObjects(slot.get, @"http://get.com");
	XCTAssertEqualObjects(slot.put, @"http://put.com");
	
	[self.slotResponseExpectation fulfill];
}

- (void)xmppHTTPFileUpload:(XMPPHTTPFileUpload *)sender didFailToAssignSlotWithError:(XMPPIQ *) iqError {
	
	[self.slotResponseExpectation fulfill];
}


- (XMPPIQ *) responseSuccessIQWithID:(NSString *) elementID {
	//	<iq from='upload.montague.tld'
	//		     id='step_03'
	//			  to='romeo@montague.tld/garden'
	//			type='result'>
	//		<slot xmlns='urn:xmpp:http:upload'>
	//			<put>https://upload.montague.tld/4a771ac1-f0b2-4a4a-9700-f2a26fa2bb67/my_juliet.png</put>
	//			<get>https://download.montague.tld/4a771ac1-f0b2-4a4a-9700-f2a26fa2bb67/my_juliet.png</get>
	//		</slot>
	//	</iq>
	
	XMPPIQ *iq = [[XMPPIQ alloc] initWithType:@"result"];
	[iq addAttributeWithName:@"id" stringValue:elementID];
	XMPPElement *slot = (XMPPElement *) [XMPPElement elementWithName:@"slot" xmlns:@"urn:xmpp:http:upload"];
	[slot addChild:[XMPPElement elementWithName:@"put" stringValue:@"http://put.com"]];
	[slot addChild:[XMPPElement elementWithName:@"get" stringValue:@"http://get.com"]];
	[iq addChild:slot];
	
	return iq;
}

- (XMPPIQ *) responseErrorIQWithID:(NSString *) elementID {
	//	<iq from='upload.montague.tld'
	//		     id='step_03'
	//			  to='romeo@montague.tld/garden'
	//			type='result'>
	//		<slot xmlns='urn:xmpp:http:upload'>
	//			<put>https://upload.montague.tld/4a771ac1-f0b2-4a4a-9700-f2a26fa2bb67/my_juliet.png</put>
	//			<get>https://download.montague.tld/4a771ac1-f0b2-4a4a-9700-f2a26fa2bb67/my_juliet.png</get>
	//		</slot>
	//	</iq>
	
	XMPPIQ *iq = [[XMPPIQ alloc] initWithType:@"error"];
	[iq addAttributeWithName:@"id" stringValue:elementID];
	XMPPElement *error = (XMPPElement *) [XMPPElement elementWithName:@"error"];
	[error addAttributeWithName:@"type" stringValue:@"wait"];
	[error addChild:[XMPPElement elementWithName:@"text" stringValue:@"Error description"]];
	[iq addChild:error];
	
	return iq;
}

@end
