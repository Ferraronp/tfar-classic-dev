#include "../src/protocol.h"

#include <iostream>
#include <string>
#include <vector>

namespace {

int failures = 0;

void expect(bool condition, const std::string& message)
{
	if (!condition)
	{
		std::cerr << "FAIL: " << message << std::endl;
		++failures;
	}
}

std::vector<std::string> values(const char* first, const char* second, const char* third)
{
	std::vector<std::string> result;
	result.push_back(first);
	result.push_back(second);
	result.push_back(third);
	return result;
}

void testNegotiation()
{
	std::vector<std::string> supported;
	supported.push_back(tfar::protocol::RADIO_ROUTE_V2);

	tfar::protocol::NegotiationResult result = tfar::protocol::negotiate(
		values("PROTOCOL", "2", "radio_route_v2,speakers_v2"), supported);
	expect(result.status == tfar::protocol::NEGOTIATION_OK, "valid negotiation succeeds");
	expect(result.version == 2, "negotiation selects v2");
	expect(result.capabilities.size() == 1 && result.capabilities[0] == "radio_route_v2",
		"negotiation returns only the supported intersection");
	expect(tfar::protocol::negotiationResponse(result) == "PROTOCOL_OK\t2\tradio_route_v2",
		"success response is stable");

	result = tfar::protocol::negotiate(values("PROTOCOL", "2", "radio_route_v2,speakers_v2"),
		std::vector<std::string>());
	expect(result.status == tfar::protocol::NEGOTIATION_OK && result.capabilities.empty(),
		"v2 can be negotiated before optional routing capabilities are shipped");
	expect(tfar::protocol::negotiationResponse(result) == "PROTOCOL_OK\t2\t-",
		"an empty capability set has an explicit representation");

	result = tfar::protocol::negotiate(values("PROTOCOL", "3", "-"), supported);
	expect(result.status == tfar::protocol::NEGOTIATION_UNSUPPORTED_VERSION,
		"unknown protocol version is rejected");
	expect(tfar::protocol::negotiationResponse(result) == "PROTOCOL_ERROR\tUNSUPPORTED_VERSION\t2",
		"unknown-version response advertises the supported version");

	result = tfar::protocol::negotiate(values("PROTOCOL", "2x", "-"), supported);
	expect(result.status == tfar::protocol::NEGOTIATION_MALFORMED, "non-decimal version is malformed");
	result = tfar::protocol::negotiate(values("PROTOCOL", "2", "radio_route_v2,radio_route_v2"), supported);
	expect(result.status == tfar::protocol::NEGOTIATION_MALFORMED, "duplicate capabilities are malformed");
	result = tfar::protocol::negotiate(values("PROTOCOL", "2", "radio route"), supported);
	expect(result.status == tfar::protocol::NEGOTIATION_MALFORMED, "invalid capability characters are malformed");
}

void testVersionedCommands()
{
	std::vector<std::string> noCapabilities;
	std::vector<std::string> routeCapability;
	routeCapability.push_back(tfar::protocol::RADIO_ROUTE_V2);

	std::vector<std::string> legacyTangent;
	legacyTangent.push_back("TANGENT");
	legacyTangent.push_back("PRESSED");
	legacyTangent.push_back("50.0_bluefor");
	legacyTangent.push_back("2000");
	legacyTangent.push_back("digital");
	tfar::protocol::CommandResult command = tfar::protocol::parseCommand(
		legacyTangent, false, 1, noCapabilities);
	expect(command.status == tfar::protocol::COMMAND_LEGACY, "legacy tangent remains on the v1 parser");

	std::vector<std::string> v2Tangent;
	v2Tangent.push_back("TANGENT");
	v2Tangent.push_back("2");
	v2Tangent.push_back("PRESSED");
	v2Tangent.push_back("tfar_fm_voice");
	v2Tangent.push_back("50000");
	v2Tangent.push_back("123");
	v2Tangent.push_back("0");
	v2Tangent.push_back("2000");
	v2Tangent.push_back("digital");

	command = tfar::protocol::parseCommand(v2Tangent, false, 1, noCapabilities);
	expect(command.status == tfar::protocol::COMMAND_NEGOTIATION_REQUIRED,
		"v2 tangent is rejected before negotiation");
	command = tfar::protocol::parseCommand(v2Tangent, true, 2, noCapabilities);
	expect(command.status == tfar::protocol::COMMAND_CAPABILITY_UNAVAILABLE,
		"v2 tangent is rejected when routing capability is unavailable");
	expect(tfar::protocol::commandErrorResponse(command)
		== "PROTOCOL_ERROR\tCAPABILITY_UNAVAILABLE\tradio_route_v2",
		"capability rejection has a stable reason code");
	command = tfar::protocol::parseCommand(v2Tangent, true, 2, routeCapability);
	expect(command.status == tfar::protocol::COMMAND_READY,
		"v2 tangent reaches the future routing parser after all gates pass");

	v2Tangent[1] = "7";
	command = tfar::protocol::parseCommand(v2Tangent, true, 2, routeCapability);
	expect(command.status == tfar::protocol::COMMAND_UNSUPPORTED_VERSION,
		"unknown command version is rejected atomically");
	v2Tangent[1] = "two";
	command = tfar::protocol::parseCommand(v2Tangent, true, 2, routeCapability);
	expect(command.status == tfar::protocol::COMMAND_MALFORMED,
		"v2-shaped command with malformed version is rejected");
	v2Tangent.pop_back();
	v2Tangent[1] = "2";
	command = tfar::protocol::parseCommand(v2Tangent, true, 2, routeCapability);
	expect(command.status == tfar::protocol::COMMAND_MALFORMED,
		"v2 command with the wrong field count is rejected");

	std::vector<std::string> legacyFreq(14, "field");
	legacyFreq[0] = "FREQ";
	legacyFreq[1] = "[]";
	command = tfar::protocol::parseCommand(legacyFreq, false, 1, noCapabilities);
	expect(command.status == tfar::protocol::COMMAND_LEGACY, "legacy FREQ remains on the v1 parser");

	std::vector<std::string> legacySpeakers;
	legacySpeakers.push_back("SPEAKERS");
	legacySpeakers.push_back("speaker-data");
	command = tfar::protocol::parseCommand(legacySpeakers, false, 1, noCapabilities);
	expect(command.status == tfar::protocol::COMMAND_LEGACY, "legacy SPEAKERS remains on the v1 parser");
}

} // namespace

int main()
{
	testNegotiation();
	testVersionedCommands();
	if (failures != 0)
	{
		std::cerr << failures << " protocol test(s) failed" << std::endl;
		return 1;
	}

	std::cout << "All protocol tests passed" << std::endl;
	return 0;
}
