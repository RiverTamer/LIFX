//
//  LIFXPacket.m
//  LIFX
//
//  Created by Karl Kraft on 7/6/22.
//  Copyright 2022-2023 Karl Kraft. Licensed under Apache License, Version 2.0.
//

#import "LIFXPacket.h"
#import "UDPSocket.h"
 
#pragma pack(push, 1)

typedef struct {
  uint16_t power;
} payload_StateLightPower;

typedef struct {
  uint16_t power;
  uint32_t duration;
} payload_SetPower;

typedef struct {
  char label[32];
} payload_SetLabel;

typedef struct {
  uint8_t reserved;
  uint16_t hue;
  uint16_t saturation;
  uint16_t brightness;
  uint16_t kelvin;
  uint32_t duration;

} payload_SetColor;

typedef struct {
  uint16_t hue;
  uint16_t saturation;
  uint16_t brightness;
  uint16_t kelvin;
  uint16_t power;
  char label[32];
  char reserved[8];
} payload_LightState;


typedef struct {
  /* frame */
  // compute based on payload
  uint16_t packetSizeIncludingPayload;

  // Must be 1024
  uint16_t protocol:12;

  // Must be 1
  uint8_t  addressable:1;
  
  // 1 for broadcast messages, 0 for targeted messages
  uint8_t  tagged:1;

  // should always be zero
  uint8_t  origin:2;
  
  // unique identifier for message, should never be zero or one due to previous firmware bugs
  uint32_t source;
  /* frame address */
  // MAC Address of the target, all zeros means send to all devices, last 2 bytes are zero
  uint8_t  target[8];
  
  // no use yet, for now always set to zero
  uint8_t  reserved[6];

  // Is a response required, for get yes, for set no
  uint8_t  res_required:1;
  
  // do we want an ack
  uint8_t  ack_required:1;

  // no use yet, for now always set to zero
  uint8_t  reserved2:6;

  uint8_t  sequence;
  /* protocol header */
  uint8_t reserved3[8];
  uint16_t type;
  uint8_t reserved4[2];
  /* variable length payload follows */
  union {
    payload_StateLightPower statePower;
    payload_SetPower setPower;
    payload_SetLabel setLabel;
    payload_SetColor setColor;
    payload_LightState lightState;
  } payload;
} lx_protocol_header_t;
#pragma pack(pop)

@implementation LIFXPacket
{
  lx_protocol_header_t networkPacket;
}

static uint8_t sequenceTracker=0;

static uint32_t sourceTracker;

+ (void)initialize
{
  
  while (sourceTracker<2) {
    sourceTracker=arc4random();
  }

}
- (instancetype)init
{
  self=[super init];
  networkPacket.packetSizeIncludingPayload=CFSwapInt16HostToLittle(36);
  networkPacket.protocol=CFSwapInt16HostToLittle(1024);
  networkPacket.addressable=1;
  networkPacket.tagged=0;
  networkPacket.origin=0;
  networkPacket.source=CFSwapInt32HostToLittle(sourceTracker);
  bzero(&networkPacket.target,8);
  
  bzero(&networkPacket.reserved,6);
  
  networkPacket.res_required=1;
  networkPacket.ack_required=0;
  
  networkPacket.reserved2=0;
  networkPacket.sequence=sequenceTracker++;
  bzero(&networkPacket.reserved3,8);
  bzero(&networkPacket.reserved4,2);
  return self;
}

+ (LIFXPacket *)readFromSocket:(UDPSocket *)socket
{
  LIFXPacket *packet = [[self alloc] init];
  [socket readSinglePacket:sizeof(lx_protocol_header_t) intoBuffer:&(packet->networkPacket)];
  return packet;
}

- (PacketType)packetType
{
  return networkPacket.type;
}

- (NSString *)packetTypeName
{
  switch(networkPacket.type) {
      // Device
    case 2: return @"GetService";
    case 3: return @"StateService";
    case 14: return @"GetHostFirmware";
    case 15: return @"StateHostFirmware";
    case 16: return @"GetWifiInfo";
    case 17: return @"StateWifiInfo";
    case 18: return @"GetWifiFirmware";
    case 19: return @"StateWifiFirmware";
    case 20: return @"GetPower";
    case 21: return @"SetPower";
    case 22: return @"StatePower";
    case 24: return @"SetLabel";
    case 25: return @"StateLabel";
    case 23: return @"GetLabel";
    case 32: return @"GetVersion";
    case 33: return @"StateVersion";
    case 34: return @"GetInfo";
    case 35: return @"StateInfo";
    case 38: return @"SetReboot";
    case 45: return @"Acknowledgement";
    case 48: return @"GetLocation";
    case 50: return @"StateLocation";
    case 49: return @"SetLocation";
    case 51: return @"GetGroup";
    case 52: return @"SetGroup";
    case 53: return @"StateGroup";
    case 58: return @"EchoRequest";
    case 59: return @"EchoResponse";
      //Light
    case 101: return @"GetColor";
    case 102: return @"SetColor";
    case 103: return @"SetWaveform";
    case 107: return @"LightState";
    case 116: return @"GetLightPower";
    case 117: return @"SetLightPower";
    case 118: return @"StateLightPower";
    case 119: return @"SetWaveformOptional";
    case 120: return @"GetInfrared";
    case 121: return @"StateInfrared";
    case 122: return @"SetInfrared";
    case 142: return @"GetHevCycle";
    case 143: return @"SetHevCycle";
    case 144: return @"StateHevCycle";
    case 145: return @"GetHevCycleConfiguration";
    case 146: return @"SetHevCycleConfiguration";
    case 147: return @"StateHevCycleConfiguration";
    case 148: return @"GetLastHevCycleResult";
    case 149: return @"StateLastHevCycleResult";
      // Unhandled
    case 223: return @"StateUnhandled";
      // mutlizone
    case 501: return @"SetColorZones";
    case 502: return @"GetColorZones";
    case 503: return @"StateZone";
    case 506: return @"StateMultiZone";
    case 507: return @"GetMultiZoneEffect";
    case 508: return @"SetMultiZoneEffect";
    case 509: return @"StateMultiZoneEffect";
    case 510: return @"SetExtendedColorZones";
    case 511: return @"GetExtendedColorZones";
    case 512: return @"StateExtendedColorZones";
      // Relay
    case 816: return @"GetRPower";
    case 817: return @"SetRPower";
    case 818: return @"StateRPower";
      // Tile
    case 701: return @"GetDeviceChain";
    case 702: return @"StateDeviceChain";
    case 703: return @"SetUserPosition";
    case 707: return @"Get64";
    case 711: return @"State64";
    case 715: return @"Set64";
    case 718: return @"GetTileEffect";
    case 719: return @"SetTileEffect";
    case 720: return @"StateTileEffect";

    default:return [NSString stringWithFormat:@"type-%02d",networkPacket.type];
  }
}

static double uint16ToFloat(uint16_t u) {
  double f=u;
  return f/65535.0;
}

- (NSString *)description
{
  NSMutableString *string = [NSMutableString string];
  [string appendFormat:@"LIFXPacket (%@)",self.packetTypeName];
  [string appendFormat:@", length=%02d",CFSwapInt16LittleToHost(networkPacket.packetSizeIncludingPayload)];
  [string appendFormat:@", addressable=%@",networkPacket.addressable ? @"YES":@"NO"];
  [string appendFormat:@", tagged=%@",networkPacket.tagged ? @"YES":@"NO"];
  [string appendFormat:@", origin=%@",networkPacket.origin ? @"YES":@"NO"];
  [string appendFormat:@", res_required=%@",networkPacket.res_required ? @"YES":@"NO"];
  [string appendFormat:@", ack_required=%@",networkPacket.ack_required ? @"YES":@"NO"];
  [string appendFormat:@", sequence=%02d",networkPacket.sequence];
  switch (networkPacket.type){
    case LightState :
      [string appendFormat:@", h=%0.2f, b=%0.2f, s=%0.2f, k=%0.2f p=%0.2f",
       uint16ToFloat(networkPacket.payload.lightState.hue),
       uint16ToFloat(networkPacket.payload.lightState.brightness),
       uint16ToFloat(networkPacket.payload.lightState.saturation),
       uint16ToFloat(networkPacket.payload.lightState.kelvin),       uint16ToFloat(networkPacket.payload.lightState.power)];
      break;
    case StatePower:
      [string appendFormat:@", p=%0.2f",uint16ToFloat(networkPacket.payload.statePower.power)];
      break;
  }
  
  return string;

//
//  /* protocol header */
//  uint8_t reserved3[9];
//  uint16_t type;
//  uint8_t reserved4[2];
//  /* variable length payload follows */
//  union {
//    payload_SetPower setPower;
//    payload_SetLabel setLabel;
//  } payload;
//} lx_protocol_header_t;
}
+(LIFXPacket *)getServicePacket
{
  LIFXPacket *packet = [[self alloc] init];
  packet->networkPacket.type=CFSwapInt16HostToLittle(2);
  return packet;
}


+(LIFXPacket *)powerOffPacket
{
  LIFXPacket *packet = [[self alloc] init];
  packet->networkPacket.packetSizeIncludingPayload=CFSwapInt16HostToLittle(36+sizeof(payload_SetPower));
  packet->networkPacket.type=CFSwapInt16HostToLittle(21);
  packet->networkPacket.payload.setPower.power=0;
  packet->networkPacket.payload.setPower.duration=500;
  return packet;
}

+(LIFXPacket *)powerOnPacket
{
  LIFXPacket *packet = [[self alloc] init];
  packet->networkPacket.packetSizeIncludingPayload=CFSwapInt16HostToLittle(36+sizeof(payload_SetPower));
  packet->networkPacket.type=CFSwapInt16HostToLittle(21);
  packet->networkPacket.payload.setPower.power=0xffff;
  packet->networkPacket.payload.setPower.duration=500;
  return packet;
}

+(LIFXPacket *)getPowerPacket
{
  LIFXPacket *packet = [[self alloc] init];
  packet->networkPacket.packetSizeIncludingPayload=CFSwapInt16HostToLittle(36);
  packet->networkPacket.type=CFSwapInt16HostToLittle(20);
  return packet;
}

- (NSString *)hexDump
{
  uint8_t *buffer = malloc(networkPacket.packetSizeIncludingPayload);
  bcopy(&networkPacket,buffer,networkPacket.packetSizeIncludingPayload);
  
  NSMutableString *s = [NSMutableString string];
  for (int x=0; x < networkPacket.packetSizeIncludingPayload;x++) {
    [s appendFormat:@"%02x",buffer[x]];
  }
  return s;
}

+(LIFXPacket *)setColor:(NSColor *)c
{
  LIFXPacket *packet = [[self alloc] init];
  CGFloat h,s,b,a;
  NSColor *c2=[c colorUsingColorSpace:NSColorSpace.extendedSRGBColorSpace];
  [c2 getHue:&h saturation:&s brightness:&b alpha:&a];
  
  packet->networkPacket.packetSizeIncludingPayload=CFSwapInt16HostToLittle(36+sizeof(payload_SetColor));
  packet->networkPacket.type=CFSwapInt16HostToLittle(102);
  packet->networkPacket.payload.setColor.hue=CFSwapInt16HostToLittle((uint16_t)(h*65535));
  packet->networkPacket.payload.setColor.saturation=CFSwapInt16HostToLittle((uint16_t)(s*65535));
  packet->networkPacket.payload.setColor.brightness=CFSwapInt16HostToLittle((uint16_t)(b*65535));
  packet->networkPacket.payload.setColor.kelvin=CFSwapInt16HostToLittle(3500);
  packet->networkPacket.payload.setColor.duration=500;

//  NSLog(@"%@",[packet hexDump]);
  return packet;
}


- (void)send:(UDPSocket *)socket
{
//  NSLog(@"send %@",self);
  [socket writeBytes:(const UInt8 *)&networkPacket length:CFSwapInt16LittleToHost(networkPacket.packetSizeIncludingPayload)];
}

- (double)powerLevel
{
  if (networkPacket.type==StatePower) {
    double f=networkPacket.payload.statePower.power;
    return f/65535.0;
  }
//  if (networkPacket.type==LightState) {
//    double f=networkPacket.payload.lightState.power;
//    return f/65535.0;
//  }
  return -1;
}
@end
