#ifndef TFAR_RADIO_ROUTE_H
#define TFAR_RADIO_ROUTE_H

#include <cerrno>
#include <cfloat>
#include <cmath>
#include <cstddef>
#include <cstdlib>
#include <sstream>
#include <string>
#include <vector>

namespace tfar {
namespace protocol {

static const std::size_t MAX_RECEIVE_ROUTES = 64;
static const std::size_t MAX_SPEAKERS = 128;
static const std::size_t MAX_SPEAKER_ROUTES = 8;
static const unsigned int MAX_FREQUENCY_KHZ = 1000000000U;

struct RadioRoute
{
	std::string waveform;
	unsigned int frequencyKhz;
	std::string protectionCode;
	unsigned int talkGroup;

	RadioRoute() : frequencyKhz(0), talkGroup(0) {}
};

struct ReceiveRoute
{
	RadioRoute route;
	int volume;
	int stereoMode;

	ReceiveRoute() : volume(0), stereoMode(0) {}
};

struct FrequencyCommand
{
	std::vector<ReceiveRoute> swRoutes;
	std::vector<ReceiveRoute> lrRoutes;
	bool hasDdRoute;
	RadioRoute ddRoute;
	bool alive;
	int voiceVolume;
	int ddVolume;
	std::string nickname;
	double wavesLevel;
	double terrainIntersectionCoefficient;
	double globalVolume;
	double voiceVolumeMultiplier;
	double receivingDistanceMultiplier;
	double speakerDistance;

	FrequencyCommand()
		: hasDdRoute(false), alive(false), voiceVolume(0), ddVolume(0),
		wavesLevel(0.0), terrainIntersectionCoefficient(0.0), globalVolume(1.0),
		voiceVolumeMultiplier(1.0), receivingDistanceMultiplier(1.0), speakerDistance(20.0) {}
};

struct TangentCommand
{
	bool pressed;
	bool longRange;
	bool diverRadio;
	RadioRoute route;
	std::string routeKeyValue;
	int range;
	std::string subtype;
	std::string nickname;

	TangentCommand() : pressed(false), longRange(false), diverRadio(false), range(0) {}
};

struct SpeakerRecord
{
	std::string radioId;
	std::vector<RadioRoute> routes;
	std::string nickname;
	std::vector<double> position;
	int volume;
	std::string vehicle;
	double waveZ;

	SpeakerRecord() : volume(0), waveZ(1.0) {}
};

inline std::vector<std::string> splitRouteFields(const std::string& value, char delimiter)
{
	std::vector<std::string> result;
	std::size_t start = 0;
	while (start <= value.size())
	{
		const std::size_t separator = value.find(delimiter, start);
		result.push_back(separator == std::string::npos
			? value.substr(start)
			: value.substr(start, separator - start));
		if (separator == std::string::npos)
			break;
		start = separator + 1;
	}
	return result;
}

inline bool isRouteIdentifier(const std::string& value)
{
	if (value.empty() || value.size() > 64)
		return false;
	for (std::size_t i = 0; i < value.size(); ++i)
	{
		const char character = value[i];
		const bool valid = (character >= 'a' && character <= 'z')
			|| (character >= 'A' && character <= 'Z')
			|| (character >= '0' && character <= '9')
			|| character == '_' || character == '.' || character == '-';
		if (!valid)
			return false;
	}
	return true;
}

inline bool isSafeRouteText(const std::string& value, bool allowEmpty, std::size_t maximumLength)
{
	if ((!allowEmpty && value.empty()) || value.size() > maximumLength)
		return false;
	for (std::size_t i = 0; i < value.size(); ++i)
	{
		const unsigned char character = static_cast<unsigned char>(value[i]);
		if (character < 32 || character == 127)
			return false;
	}
	return true;
}

inline bool parseRouteUnsigned(const std::string& value, unsigned int maximum, unsigned int& parsed)
{
	if (value.empty() || value.size() > 10 || (value.size() > 1 && value[0] == '0'))
		return false;
	unsigned int result = 0;
	for (std::size_t i = 0; i < value.size(); ++i)
	{
		const char character = value[i];
		if (character < '0' || character > '9')
			return false;
		const unsigned int digit = static_cast<unsigned int>(character - '0');
		if (digit > maximum || result > (maximum - digit) / 10U)
			return false;
		result = result * 10U + digit;
	}
	parsed = result;
	return true;
}

inline bool isRouteDecimalSyntax(const std::string& value)
{
	if (value.empty() || value.size() > 64)
		return false;
	std::size_t position = 0;
	if (value[position] == '-')
	{
		if (++position == value.size())
			return false;
	}
	const std::size_t integerStart = position;
	while (position < value.size() && value[position] >= '0' && value[position] <= '9')
		++position;
	if (position == integerStart)
		return false;
	if (position < value.size() && value[position] == '.')
	{
		const std::size_t fractionStart = ++position;
		while (position < value.size() && value[position] >= '0' && value[position] <= '9')
			++position;
		if (position == fractionStart)
			return false;
	}
	if (position < value.size() && (value[position] == 'e' || value[position] == 'E'))
	{
		++position;
		if (position < value.size() && (value[position] == '+' || value[position] == '-'))
			++position;
		const std::size_t exponentStart = position;
		while (position < value.size() && value[position] >= '0' && value[position] <= '9')
			++position;
		if (position == exponentStart)
			return false;
	}
	return position == value.size();
}

inline bool parseRouteDecimal(const std::string& value, double minimum, double maximum, double& parsed)
{
	if (!isRouteDecimalSyntax(value))
		return false;
	errno = 0;
	char* end = NULL;
	const double result = std::strtod(value.c_str(), &end);
	if (errno == ERANGE || end == NULL || *end != '\0'
		|| result < minimum || result > maximum || result < -DBL_MAX || result > DBL_MAX)
		return false;
	parsed = result;
	return true;
}

inline bool parseRouteFloat(const std::string& value, float minimum, float maximum, float& parsed)
{
	if (!isRouteDecimalSyntax(value))
		return false;
	errno = 0;
	char* end = NULL;
	const float result = std::strtof(value.c_str(), &end);
	if (errno == ERANGE || end == NULL || *end != '\0'
		|| result < minimum || result > maximum || result < -FLT_MAX || result > FLT_MAX)
		return false;
	parsed = result;
	return true;
}

inline bool parseRouteFields(const std::vector<std::string>& fields, std::size_t offset, RadioRoute& route)
{
	if (fields.size() < offset + 4 || !isRouteIdentifier(fields[offset])
		|| fields[offset + 2].size() != 3)
		return false;
	for (std::size_t i = 0; i < 3; ++i)
		if (fields[offset + 2][i] < '0' || fields[offset + 2][i] > '9')
			return false;
	unsigned int frequency = 0;
	unsigned int talkGroup = 0;
	if (!parseRouteUnsigned(fields[offset + 1], MAX_FREQUENCY_KHZ, frequency)
		|| frequency == 0 || !parseRouteUnsigned(fields[offset + 3], 9U, talkGroup))
		return false;
	RadioRoute parsed;
	parsed.waveform = fields[offset];
	parsed.frequencyKhz = frequency;
	parsed.protectionCode = fields[offset + 2];
	parsed.talkGroup = talkGroup;
	route = parsed;
	return true;
}

inline bool parseRadioRoute(const std::string& value, RadioRoute& route)
{
	if (value.empty() || value.size() > 128)
		return false;
	const std::vector<std::string> fields = splitRouteFields(value, ',');
	return fields.size() == 4 && parseRouteFields(fields, 0, route);
}

inline std::string radioRouteKey(const RadioRoute& route)
{
	std::ostringstream result;
	result << route.waveform << ',' << route.frequencyKhz << ','
		<< route.protectionCode << ',' << route.talkGroup;
	return result.str();
}

inline bool radioRoutesMatch(const RadioRoute& left, const RadioRoute& right)
{
	return left.waveform == right.waveform && left.frequencyKhz == right.frequencyKhz
		&& left.protectionCode == right.protectionCode && left.talkGroup == right.talkGroup;
}

inline bool acceptsRemoteTangent(bool routingV2Active, bool versionedCommand)
{
	return routingV2Active == versionedCommand;
}

inline bool parseReceiveRoutes(const std::string& value, std::vector<ReceiveRoute>& routes)
{
	if (value == "-")
	{
		routes.clear();
		return true;
	}
	if (value.empty() || value.size() > 8192)
		return false;
	const std::vector<std::string> entries = splitRouteFields(value, ';');
	if (entries.empty() || entries.size() > MAX_RECEIVE_ROUTES)
		return false;
	std::vector<ReceiveRoute> parsedRoutes;
	for (std::size_t i = 0; i < entries.size(); ++i)
	{
		const std::vector<std::string> fields = splitRouteFields(entries[i], ',');
		ReceiveRoute receiveRoute;
		unsigned int volume = 0;
		unsigned int stereo = 0;
		if (fields.size() != 6 || !parseRouteFields(fields, 0, receiveRoute.route)
			|| !parseRouteUnsigned(fields[4], 10U, volume)
			|| !parseRouteUnsigned(fields[5], 2U, stereo))
			return false;
		receiveRoute.volume = static_cast<int>(volume);
		receiveRoute.stereoMode = static_cast<int>(stereo);
		parsedRoutes.push_back(receiveRoute);
	}
	routes.swap(parsedRoutes);
	return true;
}

inline bool parseRadioRouteList(const std::string& value, std::size_t maximum, std::vector<RadioRoute>& routes)
{
	if (value == "-")
	{
		routes.clear();
		return true;
	}
	if (value.empty() || value.size() > 1024)
		return false;
	const std::vector<std::string> entries = splitRouteFields(value, '|');
	if (entries.empty() || entries.size() > maximum)
		return false;
	std::vector<RadioRoute> parsedRoutes;
	for (std::size_t i = 0; i < entries.size(); ++i)
	{
		RadioRoute route;
		if (!parseRadioRoute(entries[i], route))
			return false;
		parsedRoutes.push_back(route);
	}
	routes.swap(parsedRoutes);
	return true;
}

inline bool parseRoundedRouteNumber(const std::string& value, int maximum, int& parsed)
{
	double number = 0.0;
	if (!parseRouteDecimal(value, 0.0, static_cast<double>(maximum), number))
		return false;
	parsed = static_cast<int>(std::floor(number + 0.5));
	return true;
}

inline bool parseFrequencyCommand(const std::vector<std::string>& tokens, FrequencyCommand& command)
{
	if (tokens.size() != 15 || tokens[0] != "FREQ" || tokens[1] != "2")
		return false;
	FrequencyCommand parsed;
	if (!parseReceiveRoutes(tokens[2], parsed.swRoutes)
		|| !parseReceiveRoutes(tokens[3], parsed.lrRoutes))
		return false;
	if (tokens[4] != "-")
	{
		if (!parseRadioRoute(tokens[4], parsed.ddRoute))
			return false;
		parsed.hasDdRoute = true;
	}
	if (tokens[5] == "true") parsed.alive = true;
	else if (tokens[5] == "false") parsed.alive = false;
	else return false;
	if (!parseRoundedRouteNumber(tokens[6], 100000, parsed.voiceVolume)
		|| !parseRoundedRouteNumber(tokens[7], 100, parsed.ddVolume)
		|| !isSafeRouteText(tokens[8], false, 256)
		|| !parseRouteDecimal(tokens[9], -1e9, 1e9, parsed.wavesLevel)
		|| !parseRouteDecimal(tokens[10], 0.0, 1e9, parsed.terrainIntersectionCoefficient)
		|| !parseRouteDecimal(tokens[11], 0.0, 1e9, parsed.globalVolume)
		|| !parseRouteDecimal(tokens[12], 0.0, 1e9, parsed.voiceVolumeMultiplier)
		|| !parseRouteDecimal(tokens[13], 0.0, 1e9, parsed.receivingDistanceMultiplier)
		|| !parseRouteDecimal(tokens[14], 0.0, 1e9, parsed.speakerDistance))
		return false;
	parsed.nickname = tokens[8];
	command = parsed;
	return true;
}

inline bool parseTangentCommand(const std::vector<std::string>& tokens, bool remote, TangentCommand& command)
{
	if (tokens.size() != (remote ? 10U : 9U) || tokens[1] != "2"
		|| (tokens[0] != "TANGENT" && tokens[0] != "TANGENT_LR" && tokens[0] != "TANGENT_DD"))
		return false;
	TangentCommand parsed;
	if (tokens[2] == "PRESSED") parsed.pressed = true;
	else if (tokens[2] == "RELEASED") parsed.pressed = false;
	else return false;
	if (!parseRouteFields(tokens, 3, parsed.route)
		|| !parseRoundedRouteNumber(tokens[7], 10000000, parsed.range)
		|| !isRouteIdentifier(tokens[8])
		|| (remote && !isSafeRouteText(tokens[9], false, 256)))
		return false;
	parsed.longRange = tokens[0] == "TANGENT_LR";
	parsed.diverRadio = tokens[0] == "TANGENT_DD";
	parsed.routeKeyValue = radioRouteKey(parsed.route);
	parsed.subtype = tokens[8];
	if (remote) parsed.nickname = tokens[9];
	command = parsed;
	return true;
}

inline bool parseSpeakerPosition(const std::string& value, std::vector<double>& position)
{
	if (value == "[]")
	{
		position.clear();
		return true;
	}
	if (value.size() < 7 || value.size() > 192 || value[0] != '[' || value[value.size() - 1] != ']')
		return false;
	const std::vector<std::string> values = splitRouteFields(value.substr(1, value.size() - 2), ',');
	if (values.size() != 3)
		return false;
	std::vector<double> parsedPosition;
	for (std::size_t i = 0; i < values.size(); ++i)
	{
		double coordinate = 0.0;
		if (!parseRouteDecimal(values[i], -1e9, 1e9, coordinate))
			return false;
		parsedPosition.push_back(coordinate);
	}
	position.swap(parsedPosition);
	return true;
}

inline bool isSafeSpeakerVehicle(const std::string& value)
{
	if (!isSafeRouteText(value, true, 256))
		return false;
	const std::string turnoutSuffix = "_turnout";
	const std::size_t turnout = value.find(turnoutSuffix);
	if (turnout != std::string::npos)
		return turnout > 0 && turnout + turnoutSuffix.size() == value.size();

	const std::size_t separator = value.find_last_of('_');
	if (separator == std::string::npos)
		return true;
	if (separator == 0 || separator + 1 == value.size())
		return false;

	float isolation = 0.0f;
	return parseRouteFloat(value.substr(separator + 1), 0.0f, 1.0f, isolation);
}

inline bool parseSpeakersPayload(const std::string& payload, std::vector<SpeakerRecord>& speakers)
{
	if (payload == "-")
	{
		speakers.clear();
		return true;
	}
	if (payload.empty() || payload.size() > 65535)
		return false;
	const std::vector<std::string> records = splitRouteFields(payload, '\v');
	if (records.empty() || records.size() > MAX_SPEAKERS)
		return false;
	std::vector<SpeakerRecord> parsedSpeakers;
	for (std::size_t i = 0; i < records.size(); ++i)
	{
		const std::vector<std::string> fields = splitRouteFields(records[i], '\n');
		SpeakerRecord record;
		unsigned int volume = 0;
		if (fields.size() != 7 || !isSafeRouteText(fields[0], false, 256)
			|| !parseRadioRouteList(fields[1], MAX_SPEAKER_ROUTES, record.routes)
			|| record.routes.empty() || !isSafeRouteText(fields[2], true, 256)
			|| !parseSpeakerPosition(fields[3], record.position)
			|| !parseRouteUnsigned(fields[4], 10U, volume)
			|| !isSafeSpeakerVehicle(fields[5])
			|| !parseRouteDecimal(fields[6], -1e9, 1e9, record.waveZ))
			return false;
		record.radioId = fields[0];
		record.nickname = fields[2];
		record.volume = static_cast<int>(volume);
		record.vehicle = fields[5];
		parsedSpeakers.push_back(record);
	}
	speakers.swap(parsedSpeakers);
	return true;
}

} // namespace protocol
} // namespace tfar

#endif
