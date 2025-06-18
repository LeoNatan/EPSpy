//
//  EPRecorderSerialization.mm
//  EPRecorder
//
//  Created by Léo Natan on 18/6/25.
//

#import "EPRecorderSerialization.h"
#import <Security/Security.h>
#import <EPRecorder/EPRecorderOptions.h>
#import <bsm/libbsm.h>
#import <Kernel/kern/cs_blobs.h>
#import <libproc.h>

#define TO_STRING(t) @(t): @#t

#define EVAL0(...) __VA_ARGS__
#define EVAL1(...) EVAL0(EVAL0(EVAL0(__VA_ARGS__)))
#define EVAL2(...) EVAL1(EVAL1(EVAL1(__VA_ARGS__)))
#define EVAL3(...) EVAL2(EVAL2(EVAL2(__VA_ARGS__)))
#define EVAL4(...) EVAL3(EVAL3(EVAL3(__VA_ARGS__)))
#define EVAL(...)  EVAL4(EVAL4(EVAL4(__VA_ARGS__)))

#define MAP_END(...)
#define MAP_OUT
#define MAP_COMMA ,

#define MAP_GET_END2() 0, MAP_END
#define MAP_GET_END1(...) MAP_GET_END2
#define MAP_GET_END(...) MAP_GET_END1
#define MAP_NEXT0(test, next, ...) next MAP_OUT
#define MAP_NEXT1(test, next) MAP_NEXT0(test, next, 0)
#define MAP_NEXT(test, next)  MAP_NEXT1(MAP_GET_END test, next)

#define MAP0(f, x, peek, ...) f(x) MAP_NEXT(peek, MAP1)(f, peek, __VA_ARGS__)
#define MAP1(f, x, peek, ...) f(x) MAP_NEXT(peek, MAP0)(f, peek, __VA_ARGS__)

#define MAP_LIST_NEXT1(test, next) MAP_NEXT0(test, MAP_COMMA next, 0)
#define MAP_LIST_NEXT(test, next)  MAP_LIST_NEXT1(MAP_GET_END test, next)

#define MAP_LIST0(f, x, peek, ...) f(x) MAP_LIST_NEXT(peek, MAP_LIST1)(f, peek, __VA_ARGS__)
#define MAP_LIST1(f, x, peek, ...) f(x) MAP_LIST_NEXT(peek, MAP_LIST0)(f, peek, __VA_ARGS__)

/**
 * Applies the function macro `f` to each of the remaining parameters.
 */
#define MAP(f, ...) EVAL(MAP1(f, __VA_ARGS__, ()()(), ()()(), ()()(), 0))

/**
 * Applies the function macro `f` to each of the remaining parameters and
 * inserts commas between the results.
 */
#define MAP_LIST(f, ...) EVAL(MAP_LIST1(f, __VA_ARGS__, ()()(), ()()(), ()()(), 0))

static NSDictionary<NSNumber*, NSString*>* eventTypeMapping = @{
	MAP_LIST(TO_STRING,
	// The following events are available beginning in macOS 10.15
	ES_EVENT_TYPE_AUTH_EXEC,
	ES_EVENT_TYPE_AUTH_OPEN,
	ES_EVENT_TYPE_AUTH_KEXTLOAD,
	ES_EVENT_TYPE_AUTH_MMAP,
	ES_EVENT_TYPE_AUTH_MPROTECT,
	ES_EVENT_TYPE_AUTH_MOUNT,
	ES_EVENT_TYPE_AUTH_RENAME,
	ES_EVENT_TYPE_AUTH_SIGNAL,
	ES_EVENT_TYPE_AUTH_UNLINK,
	ES_EVENT_TYPE_NOTIFY_EXEC,
	ES_EVENT_TYPE_NOTIFY_OPEN,
	ES_EVENT_TYPE_NOTIFY_FORK,
	ES_EVENT_TYPE_NOTIFY_CLOSE,
	ES_EVENT_TYPE_NOTIFY_CREATE,
	ES_EVENT_TYPE_NOTIFY_EXCHANGEDATA,
	ES_EVENT_TYPE_NOTIFY_EXIT,
	ES_EVENT_TYPE_NOTIFY_GET_TASK,
	ES_EVENT_TYPE_NOTIFY_KEXTLOAD,
	ES_EVENT_TYPE_NOTIFY_KEXTUNLOAD,
	ES_EVENT_TYPE_NOTIFY_LINK,
	ES_EVENT_TYPE_NOTIFY_MMAP,
	ES_EVENT_TYPE_NOTIFY_MPROTECT,
	ES_EVENT_TYPE_NOTIFY_MOUNT,
	ES_EVENT_TYPE_NOTIFY_UNMOUNT,
	ES_EVENT_TYPE_NOTIFY_IOKIT_OPEN,
	ES_EVENT_TYPE_NOTIFY_RENAME,
	ES_EVENT_TYPE_NOTIFY_SETATTRLIST,
	ES_EVENT_TYPE_NOTIFY_SETEXTATTR,
	ES_EVENT_TYPE_NOTIFY_SETFLAGS,
	ES_EVENT_TYPE_NOTIFY_SETMODE,
	ES_EVENT_TYPE_NOTIFY_SETOWNER,
	ES_EVENT_TYPE_NOTIFY_SIGNAL,
	ES_EVENT_TYPE_NOTIFY_UNLINK,
	ES_EVENT_TYPE_NOTIFY_WRITE,
	ES_EVENT_TYPE_AUTH_FILE_PROVIDER_MATERIALIZE,
	ES_EVENT_TYPE_NOTIFY_FILE_PROVIDER_MATERIALIZE,
	ES_EVENT_TYPE_AUTH_FILE_PROVIDER_UPDATE,
	ES_EVENT_TYPE_NOTIFY_FILE_PROVIDER_UPDATE,
	ES_EVENT_TYPE_AUTH_READLINK,
	ES_EVENT_TYPE_NOTIFY_READLINK,
	ES_EVENT_TYPE_AUTH_TRUNCATE,
	ES_EVENT_TYPE_NOTIFY_TRUNCATE,
	ES_EVENT_TYPE_AUTH_LINK,
	ES_EVENT_TYPE_NOTIFY_LOOKUP,
	ES_EVENT_TYPE_AUTH_CREATE,
	ES_EVENT_TYPE_AUTH_SETATTRLIST,
	ES_EVENT_TYPE_AUTH_SETEXTATTR,
	ES_EVENT_TYPE_AUTH_SETFLAGS,
	ES_EVENT_TYPE_AUTH_SETMODE,
	ES_EVENT_TYPE_AUTH_SETOWNER,
	
	// The following events are available beginning in macOS 10.15.1
	ES_EVENT_TYPE_AUTH_CHDIR,
	ES_EVENT_TYPE_NOTIFY_CHDIR,
	ES_EVENT_TYPE_AUTH_GETATTRLIST,
	ES_EVENT_TYPE_NOTIFY_GETATTRLIST,
	ES_EVENT_TYPE_NOTIFY_STAT,
	ES_EVENT_TYPE_NOTIFY_ACCESS,
	ES_EVENT_TYPE_AUTH_CHROOT,
	ES_EVENT_TYPE_NOTIFY_CHROOT,
	ES_EVENT_TYPE_AUTH_UTIMES,
	ES_EVENT_TYPE_NOTIFY_UTIMES,
	ES_EVENT_TYPE_AUTH_CLONE,
	ES_EVENT_TYPE_NOTIFY_CLONE,
	ES_EVENT_TYPE_NOTIFY_FCNTL,
	ES_EVENT_TYPE_AUTH_GETEXTATTR,
	ES_EVENT_TYPE_NOTIFY_GETEXTATTR,
	ES_EVENT_TYPE_AUTH_LISTEXTATTR,
	ES_EVENT_TYPE_NOTIFY_LISTEXTATTR,
	ES_EVENT_TYPE_AUTH_READDIR,
	ES_EVENT_TYPE_NOTIFY_READDIR,
	ES_EVENT_TYPE_AUTH_DELETEEXTATTR,
	ES_EVENT_TYPE_NOTIFY_DELETEEXTATTR,
	ES_EVENT_TYPE_AUTH_FSGETPATH,
	ES_EVENT_TYPE_NOTIFY_FSGETPATH,
	ES_EVENT_TYPE_NOTIFY_DUP,
	ES_EVENT_TYPE_AUTH_SETTIME,
	ES_EVENT_TYPE_NOTIFY_SETTIME,
	ES_EVENT_TYPE_NOTIFY_UIPC_BIND,
	ES_EVENT_TYPE_AUTH_UIPC_BIND,
	ES_EVENT_TYPE_NOTIFY_UIPC_CONNECT,
	ES_EVENT_TYPE_AUTH_UIPC_CONNECT,
	ES_EVENT_TYPE_AUTH_EXCHANGEDATA,
	ES_EVENT_TYPE_AUTH_SETACL,
	ES_EVENT_TYPE_NOTIFY_SETACL,
	
	// The following events are available beginning in macOS 10.15.4
	ES_EVENT_TYPE_NOTIFY_PTY_GRANT,
	ES_EVENT_TYPE_NOTIFY_PTY_CLOSE,
	ES_EVENT_TYPE_AUTH_PROC_CHECK,
	ES_EVENT_TYPE_NOTIFY_PROC_CHECK,
	ES_EVENT_TYPE_AUTH_GET_TASK,
	
	// The following events are available beginning in macOS 11.0
	ES_EVENT_TYPE_AUTH_SEARCHFS,
	ES_EVENT_TYPE_NOTIFY_SEARCHFS,
	ES_EVENT_TYPE_AUTH_FCNTL,
	ES_EVENT_TYPE_AUTH_IOKIT_OPEN,
	ES_EVENT_TYPE_AUTH_PROC_SUSPEND_RESUME,
	ES_EVENT_TYPE_NOTIFY_PROC_SUSPEND_RESUME,
	ES_EVENT_TYPE_NOTIFY_CS_INVALIDATED,
	ES_EVENT_TYPE_NOTIFY_GET_TASK_NAME,
	ES_EVENT_TYPE_NOTIFY_TRACE,
	ES_EVENT_TYPE_NOTIFY_REMOTE_THREAD_CREATE,
	ES_EVENT_TYPE_AUTH_REMOUNT,
	ES_EVENT_TYPE_NOTIFY_REMOUNT,
	
	// The following events are available beginning in macOS 11.3
	ES_EVENT_TYPE_AUTH_GET_TASK_READ,
	ES_EVENT_TYPE_NOTIFY_GET_TASK_READ,
	ES_EVENT_TYPE_NOTIFY_GET_TASK_INSPECT,
	
	// The following events are available beginning in macOS 12.0
	ES_EVENT_TYPE_NOTIFY_SETUID,
	ES_EVENT_TYPE_NOTIFY_SETGID,
	ES_EVENT_TYPE_NOTIFY_SETEUID,
	ES_EVENT_TYPE_NOTIFY_SETEGID,
	ES_EVENT_TYPE_NOTIFY_SETREUID,
	ES_EVENT_TYPE_NOTIFY_SETREGID,
	ES_EVENT_TYPE_AUTH_COPYFILE,
	ES_EVENT_TYPE_NOTIFY_COPYFILE,
	
	// The following events are available beginning in macOS 13.0
	ES_EVENT_TYPE_NOTIFY_AUTHENTICATION,
	ES_EVENT_TYPE_NOTIFY_XP_MALWARE_DETECTED,
	ES_EVENT_TYPE_NOTIFY_XP_MALWARE_REMEDIATED,
	ES_EVENT_TYPE_NOTIFY_LW_SESSION_LOGIN,
	ES_EVENT_TYPE_NOTIFY_LW_SESSION_LOGOUT,
	ES_EVENT_TYPE_NOTIFY_LW_SESSION_LOCK,
	ES_EVENT_TYPE_NOTIFY_LW_SESSION_UNLOCK,
	ES_EVENT_TYPE_NOTIFY_SCREENSHARING_ATTACH,
	ES_EVENT_TYPE_NOTIFY_SCREENSHARING_DETACH,
	ES_EVENT_TYPE_NOTIFY_OPENSSH_LOGIN,
	ES_EVENT_TYPE_NOTIFY_OPENSSH_LOGOUT,
	ES_EVENT_TYPE_NOTIFY_LOGIN_LOGIN,
	ES_EVENT_TYPE_NOTIFY_LOGIN_LOGOUT,
	ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_ADD,
	ES_EVENT_TYPE_NOTIFY_BTM_LAUNCH_ITEM_REMOVE,
	
	// The following events are available beginning in macOS 14.0
	ES_EVENT_TYPE_NOTIFY_PROFILE_ADD,
	ES_EVENT_TYPE_NOTIFY_PROFILE_REMOVE,
	ES_EVENT_TYPE_NOTIFY_SU,
	ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_PETITION,
	ES_EVENT_TYPE_NOTIFY_AUTHORIZATION_JUDGEMENT,
	ES_EVENT_TYPE_NOTIFY_SUDO,
	ES_EVENT_TYPE_NOTIFY_OD_GROUP_ADD,
	ES_EVENT_TYPE_NOTIFY_OD_GROUP_REMOVE,
	ES_EVENT_TYPE_NOTIFY_OD_GROUP_SET,
	ES_EVENT_TYPE_NOTIFY_OD_MODIFY_PASSWORD,
	ES_EVENT_TYPE_NOTIFY_OD_DISABLE_USER,
	ES_EVENT_TYPE_NOTIFY_OD_ENABLE_USER,
	ES_EVENT_TYPE_NOTIFY_OD_ATTRIBUTE_VALUE_ADD,
	ES_EVENT_TYPE_NOTIFY_OD_ATTRIBUTE_VALUE_REMOVE,
	ES_EVENT_TYPE_NOTIFY_OD_ATTRIBUTE_SET,
	ES_EVENT_TYPE_NOTIFY_OD_CREATE_USER,
	ES_EVENT_TYPE_NOTIFY_OD_CREATE_GROUP,
	ES_EVENT_TYPE_NOTIFY_OD_DELETE_USER,
	ES_EVENT_TYPE_NOTIFY_OD_DELETE_GROUP,
	ES_EVENT_TYPE_NOTIFY_XPC_CONNECT,
	
	// The following events are available beginning in macOS 15.0
	ES_EVENT_TYPE_NOTIFY_GATEKEEPER_USER_OVERRIDE,
	
	// The following events are available beginning in macOS 15.4
	ES_EVENT_TYPE_NOTIFY_TCC_MODIFY,
	// ES_EVENT_TYPE_LAST is not a valid event type but a convenience
	// value for operating on the range of defined event types.
	// This value may change between releases and was available
	// beginning in macOS 10.15
	ES_EVENT_TYPE_LAST)
};

typedef struct {
	const NSString* name;
	uint32_t value;
} CSFlag;

#define CSFLAG(flag) {@#flag, flag}

// Code signing flags defined in cs_blobs.h
static const CSFlag eventCSFlagMapping[] = {
	CSFLAG(CS_VALID),               CSFLAG(CS_ADHOC),           CSFLAG(CS_GET_TASK_ALLOW),
	CSFLAG(CS_INSTALLER),           CSFLAG(CS_FORCED_LV),       CSFLAG(CS_INVALID_ALLOWED),
	CSFLAG(CS_HARD),                CSFLAG(CS_KILL),            CSFLAG(CS_CHECK_EXPIRATION),
	CSFLAG(CS_RESTRICT),            CSFLAG(CS_ENFORCEMENT),     CSFLAG(CS_REQUIRE_LV),
	CSFLAG(CS_ENTITLEMENTS_VALIDATED),                          CSFLAG(CS_NVRAM_UNRESTRICTED),
	CSFLAG(CS_RUNTIME),             CSFLAG(CS_LINKER_SIGNED),   CSFLAG(CS_ALLOWED_MACHO),
	CSFLAG(CS_EXEC_SET_HARD),       CSFLAG(CS_EXEC_SET_KILL),   CSFLAG(CS_EXEC_SET_ENFORCEMENT),
	CSFLAG(CS_EXEC_INHERIT_SIP),    CSFLAG(CS_KILLED),          CSFLAG(CS_DYLD_PLATFORM),
	CSFLAG(CS_PLATFORM_BINARY),     CSFLAG(CS_PLATFORM_PATH),   CSFLAG(CS_DEBUGGED),
	CSFLAG(CS_SIGNED),              CSFLAG(CS_DEV_CODE),		CSFLAG(CS_DATAVAULT_CONTROLLER),
};

NSString* EPRecorderStringFromCodesigningFlags(const uint32_t codesigningFlags) {
	NSMutableArray *match_flags = [NSMutableArray new];
	
	// Test which code signing flags have been set and add the matched ones to an array
	for(uint32_t i = 0; i < (sizeof eventCSFlagMapping / sizeof *eventCSFlagMapping); i++) {
		if((codesigningFlags & eventCSFlagMapping[i].value) == eventCSFlagMapping[i].value) {
			[match_flags addObject:eventCSFlagMapping[i].name];
		}
	}
	
	return [match_flags componentsJoinedByString:@" "];
}

NSString* EPRecorderStringFromStringToken(const es_string_token_t* stringToken)
{
	if(stringToken->length == 0)
	{
		return nil;
	}
	return [NSString stringWithUTF8String:stringToken->data];
}

id EPRecorderObjectForFile(const es_file_t* file)
{
	return EPRecorderStringFromStringToken(&file->path);
}

NSString* EPRecorderPathFromPID(pid_t pid)
{
	char pathbuf[PROC_PIDPATHINFO_MAXSIZE] = {0};
	proc_pidpath(pid, pathbuf, sizeof(pathbuf));
	
	return @(pathbuf);
}

NSArray* EPRecorderSignatureForAuditToken(const audit_token_t* audit_token) {
	// Convert audit_token_t to pid
	pid_t pid = audit_token_to_pid(*audit_token);
	
	// Get the SecCodeRef for the process
	SecCodeRef codeRef = NULL;
	NSDictionary* attributes = @{(__bridge NSString*)kSecGuestAttributePid: @(pid)};
	OSStatus status = SecCodeCopyGuestWithAttributes(NULL, (__bridge CFDictionaryRef)attributes,
													 kSecCSDefaultFlags, &codeRef);
	
	if (status != errSecSuccess) {
		NSLog(@"Error getting SecCodeRef: %d", (int)status);
		return nil;
	}
	
	// Get code signing information
	CFDictionaryRef signingInfo = NULL;
	status = SecCodeCopySigningInformation(codeRef, kSecCSSigningInformation, &signingInfo);
	CFRelease(codeRef);
	
	if (status != errSecSuccess) {
		NSLog(@"Error getting signing information: %d", (int)status);
		return nil;
	}
	
	// Extract certificate chain
	NSArray* certificates = [(__bridge NSDictionary*)signingInfo objectForKey:(__bridge NSString*)kSecCodeInfoCertificates];
	NSMutableArray* authorities = [NSMutableArray array];
	
	// Correct way to iterate over certificates
	for (NSInteger i = 0; i < [certificates count]; i++) {
		SecCertificateRef certRef = (__bridge SecCertificateRef)[certificates objectAtIndex:i];
		
		// Get detailed certificate information
		CFStringRef summary = SecCertificateCopySubjectSummary(certRef);
		
		if (summary) {
			NSString* authority = [NSString stringWithFormat:@"Authority=%@", (__bridge NSString*)summary];
			[authorities addObject:authority];
			CFRelease(summary);
		}
	}
	
	CFRelease(signingInfo);
	return authorities;
}

NSDictionary* EPRecorderDictionaryForProcess(const es_process_t* process, EPRecorderOptions* options)
{
	NSMutableDictionary* rv = [NSMutableDictionary new];
	pid_t pid = audit_token_to_pid(process->audit_token);
	rv[@"pid"] = @(pid);
	rv[@"executable"] = EPRecorderObjectForFile(process->executable);
	
	if(options.expandProcess == NO)
	{
		return rv;
	}
	
	rv[@"parent"] = @{
		@"pid": @(process->ppid),
		@"executable": EPRecorderPathFromPID(process->ppid),
	};
	if(process->original_ppid != process->ppid)
	{
		rv[@"original_parent"] = @{
			@"pid": @(process->original_ppid),
			@"executable": EPRecorderPathFromPID(process->original_ppid),
		};
	}
	pid_t rpid = audit_token_to_pid(process->responsible_audit_token);
	if(rpid != pid)
	{
		rv[@"responsible"] = @{
			@"pid": @(rpid),
			@"executable": EPRecorderPathFromPID(rpid),
		};
	}
	rv[@"bundleID"] = EPRecorderStringFromStringToken(&process->signing_id);
	rv[@"teamID"] = EPRecorderStringFromStringToken(&process->team_id);
	rv[@"codeSigningFlags"] = EPRecorderStringFromCodesigningFlags(process->codesigning_flags);
	rv[@"signature"] = EPRecorderSignatureForAuditToken(&process->audit_token);
	
	return rv;
}

void EPRecorderFillExecEvent(NSMutableDictionary* rv, const es_event_exec_t* exec, EPRecorderOptions* options)
{
	NSMutableDictionary* execEvent = [NSMutableDictionary new];
	execEvent[@"process"] = EPRecorderDictionaryForProcess(exec->target, options);
	if(options.recordLaunchArguments)
	{
		NSMutableArray* args = [NSMutableArray new];
		uint32_t argCount = es_exec_arg_count(exec);
		for(uint32_t idx = 1; idx < argCount; idx++) {
			es_string_token_t _arg = es_exec_arg(exec, idx);
			NSString* arg = EPRecorderStringFromStringToken(&_arg);
			if(arg != nil)
			{
				[args addObject:arg];
			}
		}
		if(args.count > 0)
		{
			execEvent[@"arguments"] = args;
		}
	}
	if(options.recordEnvironmentVariables)
	{
		NSMutableArray* env = [NSMutableArray new];
		uint32_t envCount = es_exec_env_count(exec);
		for(uint32_t idx = 0; idx < envCount; idx++) {
			es_string_token_t _envVar = es_exec_env(exec, idx);
			NSString* envVar = EPRecorderStringFromStringToken(&_envVar);
			if(envVar != nil)
			{
				[env addObject:envVar];
			}
		}
		if(env.count > 0)
		{
			execEvent[@"environment"] = env;
		}
	}
	rv[@"exec"] = execEvent;
//	rv[@"event"] = execEvent;
}

void EPRecorderFillForkEvent(NSMutableDictionary* rv, const es_event_fork_t* fork, EPRecorderOptions* options)
{
	rv[@"fork"] = EPRecorderDictionaryForProcess(fork->child, options);
}

void EPRecorderFillOpenEvent(NSMutableDictionary* rv, const es_event_open_t* open, EPRecorderOptions* options)
{
	rv[@"open"] = EPRecorderObjectForFile(open->file);
}

void EPRecorderFillWriteEvent(NSMutableDictionary* rv, const es_event_write_t* write, EPRecorderOptions* options)
{
	rv[@"write"] = EPRecorderObjectForFile(write->target);
}

void EPRecorderFillCloseEvent(NSMutableDictionary* rv, const es_event_close_t* close, EPRecorderOptions* options)
{
	rv[@"close"] = @{
		@"modified": @(close->modified),
		@"target": EPRecorderObjectForFile(close->target),
	};
}

void EPRecorderFillExitEvent(NSMutableDictionary* rv, const es_event_exit_t* exit, EPRecorderOptions* options)
{
	rv[@"exit"] = @(exit->stat);
}

static NSDictionary<NSNumber*, NSString*>* xpcConnectTypeMapping = @{
	MAP_LIST(TO_STRING,
	ES_XPC_DOMAIN_TYPE_SYSTEM,
	ES_XPC_DOMAIN_TYPE_USER,
	ES_XPC_DOMAIN_TYPE_USER_LOGIN,
	ES_XPC_DOMAIN_TYPE_SESSION,
	ES_XPC_DOMAIN_TYPE_PID,
	ES_XPC_DOMAIN_TYPE_MANAGER,
	ES_XPC_DOMAIN_TYPE_PORT,
	ES_XPC_DOMAIN_TYPE_GUI)
};

void EPRecorderFillXPCConnectEvent(NSMutableDictionary* rv, const es_event_xpc_connect_t* xpcConnect, EPRecorderOptions* options)
{
	rv[@"xpc_connect"] = @{
		@"service": EPRecorderStringFromStringToken(&xpcConnect->service_name),
		@"domainType": xpcConnectTypeMapping[@(xpcConnect->service_domain_type)],
	};
}

void EPRecorderFillEvent(NSMutableDictionary* rv, const es_message_t* message, EPRecorderOptions* options)
{
	switch (message->event_type) {
		case ES_EVENT_TYPE_NOTIFY_EXEC:
			EPRecorderFillExecEvent(rv, &message->event.exec, options);
			break;
		case ES_EVENT_TYPE_NOTIFY_OPEN:
			EPRecorderFillOpenEvent(rv, &message->event.open, options);
			break;
		case ES_EVENT_TYPE_NOTIFY_FORK:
			EPRecorderFillForkEvent(rv, &message->event.fork, options);
			break;
		case ES_EVENT_TYPE_NOTIFY_CLOSE:
			EPRecorderFillCloseEvent(rv, &message->event.close, options);
			break;
		case ES_EVENT_TYPE_NOTIFY_WRITE:
			EPRecorderFillWriteEvent(rv, &message->event.write, options);
			break;
		case ES_EVENT_TYPE_NOTIFY_XPC_CONNECT:
			EPRecorderFillXPCConnectEvent(rv, message->event.xpc_connect, options);
			break;
		case ES_EVENT_TYPE_NOTIFY_EXIT:
			EPRecorderFillExitEvent(rv, &message->event.exit, options);
			break;
		default:
			rv[@"event"] = @"Unsupported";
			break;
	}
}

NSDictionary* EPRecorderDictionaryForMessage(const es_message_t* message, EPRecorderOptions* options)
{
	if(message->process->is_es_client)
	{
		return nil;
	}
	
	if(options.ignorePlatformProcesses && message->process->is_platform_binary)
	{
		return nil;
	}
	
	NSMutableDictionary* rv = [NSMutableDictionary new];
	rv[@"type"] = eventTypeMapping[@(message->event_type)];
	rv[@"process"] = EPRecorderDictionaryForProcess(message->process, options);
	
	EPRecorderFillEvent(rv, message, options);
	
	return rv;
}
