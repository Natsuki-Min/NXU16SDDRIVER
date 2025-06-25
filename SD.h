#ifndef SD_DRIVER_H
#define SD_DRIVER_H

#include "stdint.h"

#ifdef __cplusplus
extern "C" {
#endif

// SD卡类型标记
extern uint16_t _SDType;

// 初始化SD卡控制器特殊功能寄存器
uint8_t _SDDriverInitSFR(void);

// 连接并初始化SD卡
uint8_t _SDDriverConnectCard(void);

// 结束SD卡通信
void _SDDriverEndComunication(void);

// 向SD卡发送命令
// cmd: 命令号 (0-63)
// arg: 32位命令参数
uint8_t _SDDriverSendCommand(uint8_t cmd, uint32_t arg);

// 读取单个数据块 (512字节)
// block_addr: 块地址 (LBA)
// buf: 数据缓冲区 (必须256字对齐)
uint8_t _SDDriverReadBlock(uint32_t block_addr, uint16_t* buf);

// 读取多个数据块
// block_addr: 起始块地址 (LBA)
// buf: 数据缓冲区 (必须256字对齐)
// blocks: 要读取的块数
uint8_t _SDDriverReadMultiBlocks(uint32_t block_addr, uint16_t* buf, uint16_t blocks);

// 写入单个数据块 (512字节)
// block_addr: 块地址 (LBA)
// buf: 数据缓冲区 (必须256字对齐)
uint8_t _SDDriverWriteBlock(uint32_t block_addr, uint16_t* buf);

// 写入多个数据块
// block_addr: 起始块地址 (LBA)
// buf: 数据缓冲区 (必须256字对齐)
// blocks: 要写入的块数
uint8_t _SDDriverWriteMultiBlocks(uint32_t block_addr, uint16_t* buf, uint16_t blocks);

#ifdef __cplusplus
}
#endif

#endif // SD_DRIVER_H