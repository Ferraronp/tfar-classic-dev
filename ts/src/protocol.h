#ifndef TFAR_PROTOCOL_H
#define TFAR_PROTOCOL_H

#include <cstddef>
#include <string>
#include <vector>

namespace tfar {
namespace protocol {

static const int CURRENT_VERSION = 2;
static const std::size_t MAX_CAPABILITIES = 16;
static const std::size_t MAX_CAPABILITY_LENGTH = 64;

static const char* const RADIO_ROUTE_V2 = "radio_route_v2";
static const char* const SPEAKERS_V2 = "speakers_v2";

enum NegotiationStatus
{
	NEGOTIATION_OK,
	NEGOTIATION_MALFORMED,
	NEGOTIATION_UNSUPPORTED_VERSION
};

struct NegotiationResult
{
	NegotiationStatus status;
	int version;
	std::vector<std::string> capabilities;

	NegotiationResult()
		: status(NEGOTIATION_MALFORMED), version(0)
	{
	}
};

enum CommandStatus
{
	COMMAND_LEGACY,
	COMMAND_READY,
	COMMAND_MALFORMED,
	COMMAND_UNSUPPORTED_VERSION,
	COMMAND_NEGOTIATION_REQUIRED,
	COMMAND_CAPABILITY_UNAVAILABLE
};

struct CommandResult
{
	CommandStatus status;
	int version;
	std::string capability;

	CommandResult()
		: status(COMMAND_LEGACY), version(1)
	{
	}
};

inline bool contains(const std::vector<std::string>& values, const std::string& value)
{
	for (std::size_t i = 0; i < values.size(); ++i)
	{
		if (values[i] == value)
			return true;
	}
	return false;
}

inline bool parseVersion(const std::string& value, int& version)
{
	if (value.empty() || value.size() > 3)
		return false;

	int parsed = 0;
	for (std::size_t i = 0; i < value.size(); ++i)
	{
		const char character = value[i];
		if (character < '0' || character > '9')
			return false;
		parsed = (parsed * 10) + (character - '0');
	}

	if (parsed < 1)
		return false;

	version = parsed;
	return true;
}

inline bool isCapability(const std::string& value)
{
	if (value.empty() || value.size() > MAX_CAPABILITY_LENGTH)
		return false;

	for (std::size_t i = 0; i < value.size(); ++i)
	{
		const char character = value[i];
		const bool valid = (character >= 'a' && character <= 'z')
			|| (character >= '0' && character <= '9')
			|| character == '_'
			|| character == '.'
			|| character == '-';
		if (!valid)
			return false;
	}
	return true;
}

inline bool parseCapabilities(const std::string& value, std::vector<std::string>& capabilities)
{
	capabilities.clear();
	if (value == "-")
		return true;
	if (value.empty())
		return false;

	std::size_t start = 0;
	while (start <= value.size())
	{
		const std::size_t separator = value.find(',', start);
		const std::size_t length = separator == std::string::npos
			? value.size() - start
			: separator - start;
		const std::string capability = value.substr(start, length);
		if (!isCapability(capability)
			|| contains(capabilities, capability)
			|| capabilities.size() >= MAX_CAPABILITIES)
		{
			capabilities.clear();
			return false;
		}
		capabilities.push_back(capability);

		if (separator == std::string::npos)
			break;
		start = separator + 1;
	}
	return true;
}

inline std::string serializeCapabilities(const std::vector<std::string>& capabilities)
{
	if (capabilities.empty())
		return "-";

	std::string result;
	for (std::size_t i = 0; i < capabilities.size(); ++i)
	{
		if (i > 0)
			result += ',';
		result += capabilities[i];
	}
	return result;
}

inline NegotiationResult negotiate(
	const std::vector<std::string>& tokens,
	const std::vector<std::string>& supportedCapabilities)
{
	NegotiationResult result;
	if (tokens.size() != 3 || tokens[0] != "PROTOCOL")
		return result;

	int requestedVersion = 0;
	if (!parseVersion(tokens[1], requestedVersion))
		return result;
	if (requestedVersion != CURRENT_VERSION)
	{
		result.status = NEGOTIATION_UNSUPPORTED_VERSION;
		result.version = requestedVersion;
		return result;
	}

	std::vector<std::string> requestedCapabilities;
	if (!parseCapabilities(tokens[2], requestedCapabilities))
		return result;

	result.status = NEGOTIATION_OK;
	result.version = CURRENT_VERSION;
	for (std::size_t i = 0; i < requestedCapabilities.size(); ++i)
	{
		if (contains(supportedCapabilities, requestedCapabilities[i]))
			result.capabilities.push_back(requestedCapabilities[i]);
	}
	return result;
}

inline std::string negotiationResponse(const NegotiationResult& result)
{
	if (result.status == NEGOTIATION_OK)
	{
		return std::string("PROTOCOL_OK\t")
			+ "2\t"
			+ serializeCapabilities(result.capabilities);
	}
	if (result.status == NEGOTIATION_UNSUPPORTED_VERSION)
		return "PROTOCOL_ERROR\tUNSUPPORTED_VERSION\t2";
	return "PROTOCOL_ERROR\tMALFORMED";
}

inline const char* commandCapability(const std::string& command)
{
	if (command == "FREQ"
		|| command == "TANGENT"
		|| command == "TANGENT_LR"
		|| command == "TANGENT_DD")
	{
		return RADIO_ROUTE_V2;
	}
	if (command == "SPEAKERS")
		return SPEAKERS_V2;
	return NULL;
}

inline std::size_t versionedCommandFieldCount(const std::string& command)
{
	if (command == "FREQ")
		return 15;
	if (command == "TANGENT" || command == "TANGENT_LR" || command == "TANGENT_DD")
		return 9;
	if (command == "SPEAKERS")
		return 3;
	return 0;
}

inline CommandResult parseCommand(
	const std::vector<std::string>& tokens,
	bool protocolNegotiated,
	int negotiatedVersion,
	const std::vector<std::string>& negotiatedCapabilities)
{
	CommandResult result;
	if (tokens.empty())
		return result;

	const char* requiredCapability = commandCapability(tokens[0]);
	if (requiredCapability == NULL || tokens.size() < 2)
		return result;

	int commandVersion = 0;
	const bool hasVersion = parseVersion(tokens[1], commandVersion);
	const std::size_t expectedFields = versionedCommandFieldCount(tokens[0]);
	if (!hasVersion)
	{
		if (tokens.size() == expectedFields)
			result.status = COMMAND_MALFORMED;
		return result;
	}

	result.version = commandVersion;
	result.capability = requiredCapability;
	if (commandVersion != CURRENT_VERSION)
	{
		result.status = COMMAND_UNSUPPORTED_VERSION;
		return result;
	}
	if (tokens.size() != expectedFields)
	{
		result.status = COMMAND_MALFORMED;
		return result;
	}
	if (!protocolNegotiated || negotiatedVersion != CURRENT_VERSION)
	{
		result.status = COMMAND_NEGOTIATION_REQUIRED;
		return result;
	}
	if (!contains(negotiatedCapabilities, result.capability))
	{
		result.status = COMMAND_CAPABILITY_UNAVAILABLE;
		return result;
	}

	result.status = COMMAND_READY;
	return result;
}

inline std::string commandErrorResponse(const CommandResult& result)
{
	if (result.status == COMMAND_UNSUPPORTED_VERSION)
		return "PROTOCOL_ERROR\tUNSUPPORTED_VERSION\t2";
	if (result.status == COMMAND_NEGOTIATION_REQUIRED)
		return "PROTOCOL_ERROR\tNEGOTIATION_REQUIRED";
	if (result.status == COMMAND_CAPABILITY_UNAVAILABLE)
		return std::string("PROTOCOL_ERROR\tCAPABILITY_UNAVAILABLE\t") + result.capability;
	if (result.status == COMMAND_MALFORMED)
		return "PROTOCOL_ERROR\tMALFORMED_COMMAND";
	return "PROTOCOL_ERROR\tCOMMAND_NOT_IMPLEMENTED";
}

} // namespace protocol
} // namespace tfar

#endif
