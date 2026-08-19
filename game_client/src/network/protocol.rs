use serde::{Deserialize, Serialize};

use crate::core::events::{BuildingType, ProductType};

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ClientMessage {
    Join { name: String, token: String },
    Ping,
    RequestSnapshot,
    BuildBank { x: f32, y: f32 },
    BuildStructure { building_type: BuildingType, x: f32, y: f32 },
    SpawnVehicle { x: f32, y: f32, target_x: f32, target_y: f32, speed: f32 },
    SetFactoryProduct { id: u64, product: ProductType },
}

#[derive(Serialize, Deserialize, Clone, Debug)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ServerMessage {
    Welcome { player_id: u64 },
    Pong,
    WorldSnapshot { data: WorldSnapshot },
    CommandRejected { message: String },
    Error { message: String },
    Disconnected { message: String },
}

#[derive(Serialize, Deserialize, Clone, Debug, Default)]
pub struct WorldSnapshot {
    pub tick: u64,
    pub money: i64,
    pub banks: Vec<BankState>,
    pub factories: Vec<FactoryState>,
    pub warehouses: Vec<WarehouseState>,
    pub gatherers: Vec<SimpleBuildingState>,
    pub farms: Vec<SimpleBuildingState>,
    pub vehicles: Vec<VehicleState>,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct BankState { pub id: u64, pub owner_id: u64, pub x: f32, pub y: f32 }
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct FactoryState { pub id: u64, pub owner_id: u64, pub x: f32, pub y: f32, pub level: u8, pub product: ProductType }
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct WarehouseState { pub id: u64, pub owner_id: u64, pub x: f32, pub y: f32, pub capacity: u32 }
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct SimpleBuildingState { pub id: u64, pub owner_id: u64, pub x: f32, pub y: f32 }
#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct VehicleState {
    pub id: u64,
    pub owner_id: u64,
    pub x: f32,
    pub y: f32,
    pub target_x: f32,
    pub target_y: f32,
    pub speed: f32,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_message_round_trips() {
        let message = ClientMessage::BuildBank { x: 12.0, y: -4.0 };
        let json = serde_json::to_string(&message).unwrap();
        let decoded: ClientMessage = serde_json::from_str(&json).unwrap();
        assert!(matches!(decoded, ClientMessage::BuildBank { x, y } if x == 12.0 && y == -4.0));
    }

    #[test]
    fn snapshot_envelope_round_trips() {
        let message = ServerMessage::WorldSnapshot { data: WorldSnapshot::default() };
        let json = serde_json::to_string(&message).unwrap();
        let decoded: ServerMessage = serde_json::from_str(&json).unwrap();
        assert!(matches!(decoded, ServerMessage::WorldSnapshot { data } if data.tick == 0));
    }

    #[test]
    fn disconnect_message_round_trips() {
        let message = ServerMessage::CommandRejected { message: "rejected".into() };
        let json = serde_json::to_string(&message).unwrap();
        let decoded: ServerMessage = serde_json::from_str(&json).unwrap();
        assert!(matches!(decoded, ServerMessage::CommandRejected { message } if message == "rejected"));
    }
}
