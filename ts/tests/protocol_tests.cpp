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

void testRadioRoutes()
{
	tfar::protocol::RadioRoute route;
	expect(tfar::protocol::parseRadioRoute("tfar_fm_voice,50000,000,0", route),
		"valid Open route parses");
	expect(route.waveform == "tfar_fm_voice" && route.frequencyKhz == 50000
		&& route.protectionCode == "000" && route.talkGroup == 0,
		"route fields remain structured");
	expect(tfar::protocol::radioRouteKey(route) == "tfar_fm_voice,50000,000,0",
		"route key has one canonical representation");

	tfar::protocol::RadioRoute compatible;
	expect(tfar::protocol::parseRadioRoute("tfar_fm_voice,50000,000,0", compatible)
		&& tfar::protocol::radioRoutesMatch(route, compatible),
		"Open SW and LR routes match without classname or side identity");

	tfar::protocol::RadioRoute changed;
	tfar::protocol::parseRadioRoute("other_waveform,50000,000,0", changed);
	expect(!tfar::protocol::radioRoutesMatch(route, changed), "waveform mismatch rejects reception");
	tfar::protocol::parseRadioRoute("tfar_fm_voice,50100,000,0", changed);
	expect(!tfar::protocol::radioRoutesMatch(route, changed), "frequency mismatch rejects reception");
	tfar::protocol::parseRadioRoute("tfar_fm_voice,50000,123,0", changed);
	expect(!tfar::protocol::radioRoutesMatch(route, changed), "000 does not fail-open against a keyed code");
	tfar::protocol::parseRadioRoute("tfar_fm_voice,50000,000,1", changed);
	expect(!tfar::protocol::radioRoutesMatch(route, changed), "talk-group mismatch rejects reception");

	tfar::protocol::RadioRoute keyedA;
	tfar::protocol::RadioRoute keyedB;
	tfar::protocol::parseRadioRoute("tfar_fm_voice,50000,123,0", keyedA);
	tfar::protocol::parseRadioRoute("tfar_fm_voice,50000,123,0", keyedB);
	expect(tfar::protocol::radioRoutesMatch(keyedA, keyedB),
		"equal Keyed routes match independently of radio model or side");

	expect(!tfar::protocol::parseRadioRoute("bad waveform,50000,000,0", changed),
		"unsafe waveform is rejected");
	expect(!tfar::protocol::parseRadioRoute("tfar_fm_voice,50.0,000,0", changed),
		"frequency must already be canonical integer kHz");
	expect(!tfar::protocol::parseRadioRoute("tfar_fm_voice,050000,000,0", changed),
		"non-canonical leading-zero frequency is rejected");
	expect(!tfar::protocol::parseRadioRoute("tfar_fm_voice,50000,12,0", changed),
		"protection code must contain exactly three digits");
	expect(!tfar::protocol::parseRadioRoute("tfar_fm_voice,50000,123,10", changed),
		"unsupported talk group is rejected");
	expect(tfar::protocol::acceptsRemoteTangent(false, false)
		&& !tfar::protocol::acceptsRemoteTangent(false, true),
		"Legacy receiver accepts only v1 tangents");
	expect(tfar::protocol::acceptsRemoteTangent(true, true)
		&& !tfar::protocol::acceptsRemoteTangent(true, false),
		"v2 receiver rejects v1 instead of treating it as Open");
}

void testReceiveRoutes()
{
	std::vector<tfar::protocol::ReceiveRoute> routes;
	expect(tfar::protocol::parseReceiveRoutes("-", routes) && routes.empty(),
		"dash is the explicit empty receive list");
	expect(tfar::protocol::parseReceiveRoutes(
		"tfar_fm_voice,50000,123,0,7,1;tfar_fm_voice,50000,123,0,5,2", routes)
		&& routes.size() == 2,
		"duplicate routes from two owned radios remain valid and deterministic");
	expect(routes[1].volume == 5 && routes[1].stereoMode == 2,
		"receive settings stay attached to each route entry");

	const std::size_t previousSize = routes.size();
	expect(!tfar::protocol::parseReceiveRoutes("tfar_fm_voice,50000,123,0,11,1", routes),
		"out-of-range volume is rejected");
	expect(routes.size() == previousSize, "malformed receive list does not partially replace state");
	expect(!tfar::protocol::parseReceiveRoutes("tfar_fm_voice,50000,123,0,7,3", routes),
		"out-of-range stereo mode is rejected");
}

void testStructuredCommands()
{
	std::vector<std::string> frequency;
	frequency.push_back("FREQ");
	frequency.push_back("2");
	frequency.push_back("tfar_fm_voice,50000,123,0,7,1");
	frequency.push_back("tfar_fm_voice,50000,123,0,8,2");
	frequency.push_back("tfar_dd,35000,000,0");
	frequency.push_back("true");
	frequency.push_back("20");
	frequency.push_back("7");
	frequency.push_back("Alice");
	frequency.push_back("1");
	frequency.push_back("7");
	frequency.push_back("1");
	frequency.push_back("1");
	frequency.push_back("1");
	frequency.push_back("20");

	tfar::protocol::FrequencyCommand frequencyCommand;
	expect(tfar::protocol::parseFrequencyCommand(frequency, frequencyCommand),
		"well-formed v2 FREQ parses atomically");
	expect(frequencyCommand.swRoutes.size() == 1 && frequencyCommand.lrRoutes.size() == 1
		&& frequencyCommand.hasDdRoute,
		"v2 FREQ keeps SW, LR and DD routes separate");
	const std::string previousLrRoute = tfar::protocol::radioRouteKey(
		frequencyCommand.lrRoutes[0].route);
	frequency[3] = "tfar_fm_voice,50000,123,0,8,9";
	expect(!tfar::protocol::parseFrequencyCommand(frequency, frequencyCommand),
		"one malformed route rejects the complete FREQ update");
	expect(frequencyCommand.lrRoutes.size() == 1
		&& tfar::protocol::radioRouteKey(frequencyCommand.lrRoutes[0].route) == previousLrRoute,
		"malformed FREQ preserves the previous complete state");

	std::vector<std::string> tangent;
	tangent.push_back("TANGENT_LR");
	tangent.push_back("2");
	tangent.push_back("PRESSED");
	tangent.push_back("tfar_fm_voice");
	tangent.push_back("50000");
	tangent.push_back("123");
	tangent.push_back("0");
	tangent.push_back("20000");
	tangent.push_back("digital_lr");
	tfar::protocol::TangentCommand tangentCommand;
	expect(tfar::protocol::parseTangentCommand(tangent, false, tangentCommand)
		&& tangentCommand.longRange && tangentCommand.pressed
		&& tangentCommand.routeKeyValue == "tfar_fm_voice,50000,123,0",
		"local v2 tangent produces the canonical routing key");
	tangent.push_back("Bob");
	expect(tfar::protocol::parseTangentCommand(tangent, true, tangentCommand)
		&& tangentCommand.nickname == "Bob",
		"broadcast v2 tangent requires a bounded nickname");
	tangent[2] = "PRESS";
	expect(!tfar::protocol::parseTangentCommand(tangent, true, tangentCommand),
		"unknown tangent action is rejected");
}

void testStructuredSpeakers()
{
	std::vector<tfar::protocol::SpeakerRecord> speakers;
	expect(tfar::protocol::parseSpeakersPayload("-", speakers) && speakers.empty(),
		"dash is the explicit empty speaker payload");
	const std::string record = std::string("radio-1\n")
		+ "tfar_fm_voice,50000,123,0|tfar_fm_voice,50100,123,0\n"
		+ "Alice\n[1,2,3]\n7\nno\n1";
	expect(tfar::protocol::parseSpeakersPayload(record, speakers)
		&& speakers.size() == 1 && speakers[0].routes.size() == 2
		&& speakers[0].position.size() == 3,
		"structured speaker routes and coordinates parse");
	expect(!tfar::protocol::parseSpeakersPayload(std::string("\v") + record, speakers),
		"legacy leading vertical-tab is rejected by the v2 parser");
	const std::string unsafeVehicle = std::string("radio-1\n")
		+ "tfar_fm_voice,50000,123,0\nAlice\n[1,2,3]\n7\nvehicle_not-a-number\n1";
	expect(!tfar::protocol::parseSpeakersPayload(unsafeVehicle, speakers),
		"malformed vehicle isolation cannot reach throwing numeric conversion");
	expect(speakers.size() == 1 && speakers[0].routes.size() == 2,
		"malformed speaker payload preserves the previous complete state");
	const std::string isolatedVehicle = std::string("radio-1\n")
		+ "tfar_fm_voice,50000,123,0\nAlice\n[1,2,3]\n7\n1:2_0.3\n1";
	expect(tfar::protocol::parseSpeakersPayload(isolatedVehicle, speakers),
		"generated vehicle isolation descriptor remains valid");
	const std::string underflowVehicle = std::string("radio-1\n")
		+ "tfar_fm_voice,50000,123,0\nAlice\n[1,2,3]\n7\n1:2_1e-100\n1";
	expect(!tfar::protocol::parseSpeakersPayload(underflowVehicle, speakers),
		"speaker isolation that would make std::stof throw is rejected");
}

} // namespace

int main()
{
	testNegotiation();
	testVersionedCommands();
	testRadioRoutes();
	testReceiveRoutes();
	testStructuredCommands();
	testStructuredSpeakers();
	if (failures != 0)
	{
		std::cerr << failures << " protocol test(s) failed" << std::endl;
		return 1;
	}

	std::cout << "All protocol tests passed" << std::endl;
	return 0;
}
